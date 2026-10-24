import SwiftUI

struct DockSettingsView: View {
    @StateObject private var dock = DockIntegrationService()
    @ViewState private var proposedEdge: DockEdge = .left
    @ViewState private var proposedAutoHide = true
    @ViewState private var initialized = false

    var body: some View {
        Surface(title: "macOS Dock", subtitle: "Optionally move the Dock away from your taskbar.") {
            HStack {
                Text("Detected: \(dock.current.edge.title), auto-hide \(dock.current.autoHide ? "on" : "off")")
                    .font(.system(size: 12))
                Spacer()
                Button("Refresh") { dock.refresh() }
            }
            SettingRow(title: "Proposed Dock edge") {
                Picker("Dock edge", selection: $proposedEdge) {
                    ForEach(DockEdge.allCases) { edge in Text(edge.title).tag(edge) }
                }.labelsHidden().frame(width: 170)
            }
            Toggle("Automatically hide the macOS Dock", isOn: $proposedAutoHide).toggleStyle(.switch)
            Text("Proposed: \(proposedEdge.title), auto-hide \(proposedAutoHide ? "on" : "off")")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Text("Apply changes only the Dock's edge and auto-hide settings. The Dock briefly restarts. TaskPane saves the original values locally so you can restore them later.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Apply Dock setup") { dock.apply(DockConfiguration(edge: proposedEdge, autoHide: proposedAutoHide)) }
                    .buttonStyle(.borderedProminent)
                if dock.hasBackup {
                    Button("Restore original Dock setup") { dock.restore() }.disabled(!dock.canRestore)
                }
            }
            if let original = dock.originalDescription {
                Text("Saved original: \(original)").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if dock.hasBackup && !dock.canRestore {
                Text("The Dock has changed since TaskPane last adjusted it. Your newer choices are kept; restoration is disabled.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Keep current Dock setup and clear backup") { dock.keepCurrentSetup() }
                    .buttonStyle(.bordered)
            }
            if let notice = dock.notice { Text(notice).font(.system(size: 11)).foregroundStyle(.secondary) }
            if let error = dock.error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
        }
        .onAppear {
            dock.refresh()
            if !initialized {
                // Suggest a side placement away from a bottom taskbar, but do not
                // apply it until the user presses the explicit action above.
                proposedEdge = dock.current.edge == .bottom ? .left : dock.current.edge
                proposedAutoHide = true
                initialized = true
            }
        }
    }
}
