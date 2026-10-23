import AppKit
import Combine
import Darwin
import Foundation
import IOKit.ps
import SystemConfiguration

struct MetricSnapshot: Sendable {
    var cpuPercent: Double?
    var memoryUsedBytes: Double
    var memoryTotalBytes: Double
    var networkDownBytesPerSecond: Double?
    var networkUpBytesPerSecond: Double?
    var batteryPercent: Double?
    var batteryCharging: Bool
    var timestamp: Date

    var memoryPercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return min(100, max(0, memoryUsedBytes / memoryTotalBytes * 100))
    }

    static var empty: MetricSnapshot {
        MetricSnapshot(
            cpuPercent: nil,
            memoryUsedBytes: 0,
            memoryTotalBytes: Double(ProcessInfo.processInfo.physicalMemory),
            networkDownBytesPerSecond: nil,
            networkUpBytesPerSecond: nil,
            batteryPercent: nil,
            batteryCharging: false,
            timestamp: Date()
        )
    }
}

@MainActor
final class MetricsService: ObservableObject {
    @Published var snapshot: MetricSnapshot = .empty
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []

    private let samplingQueue = DispatchQueue(label: "TaskPane.metrics", qos: .utility)
    private let sampler = MetricSampler()
    private var timer: DispatchSourceTimer?
    private var interval: Double = 2
    private var generation: UInt64 = 0
    private var wakeObserver: NSObjectProtocol?

    init() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resetAfterWake()
            }
        }
        start()
    }

    deinit {
        timer?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func setInterval(_ seconds: Double) {
        guard seconds.isFinite else { return }
        let newInterval = min(60, max(1, seconds))
        guard newInterval != interval else { return }
        interval = newInterval
        if timer != nil {
            stop()
            start()
        }
    }

    func start() {
        guard timer == nil else { return }
        generation &+= 1
        let currentGeneration = generation
        let sampler = sampler
        let maximumGap = max(10, interval * 4)
        samplingQueue.async { sampler.resetDeltas() }

        let timer = DispatchSource.makeTimerSource(queue: samplingQueue)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(Int((interval * 1_000).rounded())),
            leeway: .milliseconds(200)
        )
        timer.setEventHandler { [weak self, sampler] in
            let value = sampler.sample(maximumGap: maximumGap)
            Task { @MainActor [weak self] in
                guard let self, self.timer != nil,
                      self.generation == currentGeneration else { return }
                self.snapshot = value
                if let cpu = value.cpuPercent {
                    self.cpuHistory.append(cpu)
                    self.cpuHistory = Array(self.cpuHistory.suffix(60))
                }
                self.memoryHistory.append(value.memoryPercent)
                self.memoryHistory = Array(self.memoryHistory.suffix(60))
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        generation &+= 1
        timer?.cancel()
        timer = nil
    }

    private func resetAfterWake() {
        // A fresh baseline prevents a sleep interval from becoming a CPU or network spike.
        if timer != nil {
            stop()
            start()
        } else {
            let sampler = sampler
            samplingQueue.async { sampler.resetDeltas() }
        }
    }
}

// Mutable sampling state is confined to MetricsService's serial sampling queue.
private final class MetricSampler: @unchecked Sendable {
    private struct NetworkCounters {
        let interface: String
        let index: UInt32
        let received: UInt64
        let sent: UInt64
    }

    private var previousCPU: [UInt32]?
    private var previousNetwork: NetworkCounters?
    private var previousUptime: TimeInterval?
    private var lastMemoryUsed: Double = 0
    private let hostPort = mach_host_self()

    deinit {
        mach_port_deallocate(mach_task_self_, hostPort)
    }

    func resetDeltas() {
        previousCPU = nil
        previousNetwork = nil
        previousUptime = nil
    }

    func sample(maximumGap: TimeInterval) -> MetricSnapshot {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = previousUptime.map { uptime - $0 }
        if let elapsed, elapsed <= 0 || elapsed > maximumGap {
            resetDeltas()
        }
        let usableElapsed = previousUptime.map { uptime - $0 }
        let cpu = cpuUsage()
        let memoryTotal = Double(ProcessInfo.processInfo.physicalMemory)
        if let memory = usedMemoryBytes() {
            lastMemoryUsed = min(memoryTotal, max(0, memory))
        }
        let network = networkRates(elapsed: usableElapsed)
        let battery = batteryState()
        previousUptime = uptime
        return MetricSnapshot(
            cpuPercent: cpu,
            memoryUsedBytes: lastMemoryUsed,
            memoryTotalBytes: memoryTotal,
            networkDownBytesPerSecond: network.down,
            networkUpBytesPerSecond: network.up,
            batteryPercent: battery.percent,
            batteryCharging: battery.charging,
            timestamp: Date()
        )
    }

    private func cpuUsage() -> Double? {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        let result = host_processor_info(
            hostPort, PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &count
        )
        guard result == KERN_SUCCESS, let info else {
            previousCPU = nil
            return nil
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let stateCount = Int(CPU_STATE_MAX)
        let valueCount = Int(processorCount) * stateCount
        guard valueCount > 0, Int(count) >= valueCount else {
            previousCPU = nil
            return nil
        }
        let current = (0..<valueCount).map { UInt32(bitPattern: info[$0]) }
        defer { previousCPU = current }
        guard let previous = previousCPU, previous.count == current.count else { return nil }

        var total: UInt64 = 0
        var idle: UInt64 = 0
        for index in current.indices {
            // CPU counters are unsigned 32-bit tick counters and may wrap on a long uptime.
            let delta = UInt64(current[index] &- previous[index])
            total += delta
            if index % stateCount == Int(CPU_STATE_IDLE) { idle += delta }
        }
        guard total > 0 else { return nil }
        return min(100, max(0, Double(total - idle) / Double(total) * 100))
    }

    private func usedMemoryBytes() -> Double? {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(hostPort, &pageSize) == KERN_SUCCESS else { return nil }
        // File-backed and purgeable pages are reclaimable caches, not app memory.
        // Compressed memory uses its physical compressor pages, not the uncompressed total.
        let resident = Double(statistics.active_count) + Double(statistics.inactive_count)
        let reclaimable = Double(statistics.external_page_count) + Double(statistics.purgeable_count)
        let app = max(0, resident - reclaimable)
        let usedPages = app + Double(statistics.wire_count) + Double(statistics.compressor_page_count)
        return usedPages * Double(pageSize)
    }

    private func networkRates(elapsed: TimeInterval?) -> (down: Double?, up: Double?) {
        guard let current = interfaceCounters() else {
            previousNetwork = nil
            return (nil, nil)
        }
        defer { previousNetwork = current }
        guard let previous = previousNetwork, previous.interface == current.interface,
              previous.index == current.index,
              let elapsed, elapsed > 0,
              let down = counterDelta(current.received, previous.received),
              let up = counterDelta(current.sent, previous.sent) else { return (nil, nil) }
        return (Double(down) / elapsed, Double(up) / elapsed)
    }

    private func counterDelta(_ current: UInt64, _ previous: UInt64) -> UInt64? {
        // These are 64-bit counters; a decrease means the interface reset. A fresh
        // baseline is safer than treating a reset as an implausibly large transfer.
        current >= previous ? current - previous : nil
    }

    private func interfaceCounters() -> NetworkCounters? {
        guard let data = routeInterfaceData(), let candidates = routeCounterCandidates(data) else { return nil }
        // Count one routed interface, not a bridge/VPN plus its underlying physical link.
        for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
            if let state = SCDynamicStoreCopyValue(nil, key as CFString) as? [String: Any],
               let name = state["PrimaryInterface"] as? String,
               let candidate = candidates[name] { return candidate }
        }
        // Network configuration may briefly refer to an interface that disappeared.
        // Prefer a physical link, then a deterministic fallback, without summing links.
        let physical = candidates.keys.filter { $0.hasPrefix("en") }.sorted()
        let names = physical.isEmpty ? candidates.keys.sorted() : physical
        return names.first.flatMap { candidates[$0] }
    }

    private func routeInterfaceData() -> Data? {
        // NET_RT_IFLIST2 supplies if_msghdr2/if_data64. The legacy getifaddrs
        // if_data byte counters wrap every 4 GiB, even at an ordinary 60s interval.
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        let maximumBytes = 4 * 1_024 * 1_024
        for _ in 0..<3 {
            var required = 0
            guard sysctl(&mib, u_int(mib.count), nil, &required, nil, 0) == 0,
                  required > 0, required <= maximumBytes else { return nil }
            var data = Data(count: required)
            var actual = required
            let (result, errorCode) = data.withUnsafeMutableBytes { buffer in
                let result = sysctl(&mib, u_int(mib.count), buffer.baseAddress, &actual, nil, 0)
                return (result, errno)
            }
            if result != 0 {
                // A link/address may have appeared between the size and data calls.
                if errorCode == ENOMEM { continue }
                return nil
            }
            guard actual > 0, actual <= required else { return nil }
            data.removeSubrange(actual..<data.count)
            return data
        }
        return nil
    }

    private func routeCounterCandidates(_ data: Data) -> [String: NetworkCounters]? {
        data.withUnsafeBytes { buffer in
            var candidates: [String: NetworkCounters] = [:]
            var offset = 0
            let headerSize = MemoryLayout<if_msghdr2>.size
            while offset < buffer.count {
                // Every route message starts with length, version and type. Reads
                // use loadUnaligned because following messages need not be aligned.
                guard buffer.count - offset >= 4 else { return nil }
                let length = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard length >= 4, length <= buffer.count - offset else { return nil }
                if buffer[offset + 2] == UInt8(RTM_VERSION), buffer[offset + 3] == UInt8(RTM_IFINFO2) {
                    guard length >= headerSize else { return nil }
                    let message = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let flags = UInt32(bitPattern: message.ifm_flags)
                    if flags & UInt32(IFF_UP) != 0, flags & UInt32(IFF_RUNNING) != 0,
                       flags & UInt32(IFF_LOOPBACK) == 0 {
                        let index = UInt32(message.ifm_index)
                        var nameBuffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                        if if_indextoname(index, &nameBuffer) != nil {
                            let name = String(cString: nameBuffer)
                            candidates[name] = NetworkCounters(
                                interface: name, index: index,
                                received: message.ifm_data.ifi_ibytes,
                                sent: message.ifm_data.ifi_obytes
                            )
                        }
                    }
                }
                offset += length
            }
            return candidates
        }
    }

    private func batteryState() -> (percent: Double?, charging: Bool) {
        guard let information = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(information)?.takeRetainedValue() as? [CFTypeRef]
        else { return (nil, false) }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(information, source)?.takeUnretainedValue()
                    as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? NSNumber,
                  let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
                  maximum.doubleValue > 0 else { continue }
            let percent = min(100, max(0, current.doubleValue / maximum.doubleValue * 100))
            let charging = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue ?? false
            return (percent, charging)
        }
        return (nil, false)
    }
}
