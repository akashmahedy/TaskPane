import AppKit
import ApplicationServices
import Combine

/// Reads only badge text exposed by the system Dock's application items. It
/// never requests Accessibility, enumerates notifications or opens other apps.
/// Some macOS versions/apps expose no status label; the correct fallback is no
/// badge rather than an invented count.
@MainActor
final class ApplicationBadgeService: ObservableObject {
    static let shared = ApplicationBadgeService()
    @Published private(set) var labelsByBundleIdentifier: [String: String] = [:]

    private let worker = DispatchQueue(label: "app.taskpane.dock-badges", qos: .utility)
    private var timer: Timer?
    private var enabled = false
    private var inFlight = false
    private var generation: UInt64 = 0

    func update(enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        generation &+= 1
        timer?.invalidate()
        timer = nil
        guard enabled else {
            labelsByBundleIdentifier = [:]
            return
        }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func stop() { update(enabled: false) }

    deinit { timer?.invalidate() }

    private func refresh() {
        guard enabled, !inFlight else { return }
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              !dock.isTerminated else {
            labelsByBundleIdentifier = [:]
            return
        }
        let pid = dock.processIdentifier
        let currentGeneration = generation
        inFlight = true
        worker.async { [weak self] in
            let labels = Self.readDockLabels(pid: pid)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.inFlight = false
                guard self.enabled, self.generation == currentGeneration else {
                    // A fresh enable may have arrived while an old read was in
                    // flight. Schedule its new read; never publish old results.
                    if self.enabled { self.refresh() }
                    return
                }
                if self.labelsByBundleIdentifier != labels { self.labelsByBundleIdentifier = labels }
            }
        }
    }

    nonisolated private static func readDockLabels(pid: pid_t) -> [String: String] {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication(processIdentifier: pid),
              dock.bundleIdentifier == "com.apple.dock", !dock.isTerminated else { return [:] }
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.05)
        let attributes = [kAXRoleAttribute, kAXSubroleAttribute, kAXURLAttribute, "AXStatusLabel"] as CFArray
        var pending = children(of: root).map { ($0, 0) }
        var examined = 0
        var result: [String: String] = [:]
        // Dock exposes its icons under an AXList. Only descend system lists;
        // never follow references to windows, menus or other applications.
        while !pending.isEmpty, examined < 160 {
            let (element, depth) = pending.removeFirst()
            examined += 1
            var owner: pid_t = 0
            guard AXUIElementGetPid(element, &owner) == .success, owner == pid else { continue }
            AXUIElementSetMessagingTimeout(element, 0.05)
            var raw: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(element, attributes, [], &raw) == .success,
                  let values = raw as? [Any], values.count == 4 else { continue }
            let role = values[0] as? String
            let subrole = values[1] as? String
            if role == kAXListRole, depth < 2 {
                pending.append(contentsOf: children(of: element).map { ($0, depth + 1) })
            }
            guard role == "AXDockItem", subrole == "AXApplicationDockItem",
                  let label = values[3] as? String,
                  !label.isEmpty, label.count <= 12,
                  !label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  let url = fileURL(values[2]), url.pathExtension.lowercased() == "app",
                  let identifier = Bundle(url: url)?.bundleIdentifier, !identifier.isEmpty else { continue }
            result[identifier] = label
        }
        return result
    }

    nonisolated private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else { return [] }
        return Array(elements.prefix(160))
    }

    nonisolated private static func fileURL(_ value: Any) -> URL? {
        if let url = value as? URL, url.isFileURL { return url.standardizedFileURL }
        if let string = value as? String, let url = URL(string: string), url.isFileURL { return url.standardizedFileURL }
        return nil
    }
}
