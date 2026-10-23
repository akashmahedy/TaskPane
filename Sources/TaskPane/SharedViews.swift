import AppKit
import SwiftUI
import TaskPaneCore

// The macOS 27 CLT SDK also exports a same-named State macro without its plugin.
// Naming the existing property-wrapper type explicitly keeps CLT builds portable.
typealias ViewState<Value> = SwiftUI.State<Value>

extension Color {
    init(taskPaneHex: String) {
        let value = UInt64(taskPaneHex, radix: 16) ?? 0x5B8CFF
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

enum MetricFormatting {
    static func bytes(_ bytes: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(0, min(bytes.isFinite ? bytes : 0, Double(Int64.max / 2)))), countStyle: .memory)
    }
    static func speed(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        if value < 1024 { return "\(Int(max(0, value))) B/s" }
        if value < 1_048_576 { return String(format: "%.0f KB/s", value / 1024) }
        return String(format: "%.1f MB/s", value / 1_048_576)
    }
    static func text(_ kind: WidgetKind, snapshot: MetricSnapshot, compact: Bool = false) -> String {
        switch kind {
        case .cpu: return snapshot.cpuPercent.map { String(format: compact ? "%.0f%%" : "CPU %.0f%%", $0) } ?? "CPU —"
        case .memory: return String(format: compact ? "%.0f%%" : "RAM %.0f%%", snapshot.memoryPercent)
        case .network: return "↓\(speed(snapshot.networkDownBytesPerSecond)) ↑\(speed(snapshot.networkUpBytesPerSecond))"
        case .battery: return snapshot.batteryPercent.map { String(format: snapshot.batteryCharging ? "↗ %.0f%%" : "BAT %.0f%%", $0) } ?? "No battery"
        case .clock: return Date.now.formatted(date: .omitted, time: .shortened)
        }
    }
    static func symbol(_ kind: WidgetKind) -> String {
        switch kind { case .cpu: return "cpu"; case .memory: return "memorychip"; case .network: return "arrow.up.arrow.down"; case .battery: return "battery.100"; case .clock: return "clock" }
    }
}

@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]
    static func icon(path: String?) -> NSImage {
        guard let path else { return NSImage(systemSymbolName: "app", accessibilityDescription: nil)! }
        if let image = cache[path] { return image }
        let image = NSWorkspace.shared.icon(forFile: path)
        if cache.count > 300 { cache.removeAll() }
        cache[path] = image
        return image
    }
    static func icon(bundleIdentifier: String?, pid: Int32) -> NSImage {
        let app = NSRunningApplication(processIdentifier: pid)
        return icon(path: app?.bundleURL?.path)
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color = .accentColor
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let valid = values.map { $0.isFinite ? min(100, max(0, $0)) : 0 }
                guard valid.count > 1 else { return }
                for (index, value) in valid.enumerated() {
                    let point = CGPoint(x: CGFloat(index) / CGFloat(valid.count - 1) * proxy.size.width,
                                        y: proxy.size.height * (1 - value / 100))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }.accessibilityHidden(true)
    }
}

struct Surface<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary) }
                }
            }
            content
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 20)
            content
        }.frame(minHeight: 32)
    }
}
