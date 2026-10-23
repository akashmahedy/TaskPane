import AppKit
import Foundation

@MainActor
enum TaskPaneDiagnostics {
    static func run() {
        let metrics = MetricsService()
        let windows = WindowService()
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            let snapshot = metrics.snapshot
            let validMemory = snapshot.memoryTotalBytes > 0 && snapshot.memoryUsedBytes > 0 &&
                snapshot.memoryUsedBytes <= snapshot.memoryTotalBytes && !metrics.memoryHistory.isEmpty
            let validCPU = snapshot.cpuPercent.map { $0.isFinite && (0...100).contains($0) } ?? false
            let result: [String: Any] = [
                "app": "TaskPane", "version": "0.1.0", "creator": "akashmahedy",
                "validCPU": validCPU, "validMemory": validMemory,
                "cpuPercent": snapshot.cpuPercent as Any? ?? NSNull(),
                "memoryUsedBytes": snapshot.memoryUsedBytes,
                "memoryTotalBytes": snapshot.memoryTotalBytes,
                "networkDownBytesPerSecond": snapshot.networkDownBytesPerSecond as Any? ?? NSNull(),
                "networkUpBytesPerSecond": snapshot.networkUpBytesPerSecond as Any? ?? NSNull(),
                "batteryPercent": snapshot.batteryPercent as Any? ?? NSNull(),
                "windowCount": windows.windows.count, "runningAppCount": windows.apps.count,
                "displayCount": NSScreen.screens.count,
                "accessibilityGranted": windows.accessibilityGranted,
                "cpuHistoryCount": metrics.cpuHistory.count,
                "memoryHistoryCount": metrics.memoryHistory.count
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) { print(text) }
            metrics.stop(); windows.stop()
            exit(validCPU && validMemory ? 0 : 1)
        }
        RunLoop.main.run()
    }
}
