import SwiftUI

struct DockSettingsView: View {
    @ObservedObject private var dock = DockIntegrationService.shared
    @ViewState private var proposedEdge: DockEdge = .left
    @ViewState private var proposedAutoHide = true
    @ViewState private var proposedFullyHidden = false
    @ViewState private var restoreOnQuit = true
    @ViewState private var initialized = false

    var body: some View {
        Surface(title: "macOS Dock", subtitle: "Optionally move the Dock away from your taskbar.") {
            HStack {
                Text("Detected: \(dock.current.edge.title), \(dock.current.fullyHidden ? "fully hidden" : dock.current.autoHide ? "auto-hide on" : "auto-hide off")")
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
            Toggle("Completely hide the macOS Dock", isOn: $proposedFullyHidden).toggleStyle(.switch)
            Toggle("Restore original Dock settings when TaskPane quits", isOn: $restoreOnQuit).toggleStyle(.switch)
            Text("Full hiding disables normal edge reveal using the Dock's reveal delay. Mission Control and other system screens can still show the Dock. A local backup survives an unexpected app exit; use Restore after reopening.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Text("Proposed: \(proposedEdge.title), \(proposedFullyHidden ? "fully hidden" : proposedAutoHide ? "auto-hide on" : "auto-hide off") · Apply to save")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Text("Apply changes the Dock's edge, auto-hide and reveal delay. The Dock briefly restarts. TaskPane saves the original values locally so you can restore them later.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Apply Dock setup") { dock.apply(DockConfiguration(edge: proposedEdge, autoHide: proposedAutoHide, fullyHidden: proposedFullyHidden), restoreOnQuit: restoreOnQuit) }
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
                proposedFullyHidden = dock.current.fullyHidden
                restoreOnQuit = dock.restoreWhenQuitting
                initialized = true
            }
        }
    }
}
