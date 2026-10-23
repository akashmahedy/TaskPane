import AppKit
import SwiftUI

/// The bar presents this as a transient popover on the clicked display.
struct StartMenuView: View {
    @ObservedObject var launcher: LauncherService
    @ObservedObject var settings: SettingsStore
    let height: CGFloat
    let dismiss: () -> Void
    @ViewState private var query = ""
    @ViewState private var presentationID = UUID()
    @ViewState private var launchRequest: UUID?
    @FocusState private var searchFocused: Bool

    private var results: [LauncherEntry] {
        launcher.applications.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }
    private var pinned: [LauncherEntry] {
        settings.preferences.pinnedApplicationPaths.map { path in
            launcher.applications.first { $0.id == path } ?? LauncherEntry(
                name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
                url: URL(fileURLWithPath: path), bundleIdentifier: nil)
        }
    }
    private var groupedResults: [String: [LauncherEntry]] {
        Dictionary(grouping: results) { String($0.name.prefix(1)).uppercased() }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search applications", text: $query).textFieldStyle(.plain)
                    .focused($searchFocused).onSubmit { if let first = results.first { open(first) } }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
                Button(action: dismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Close Start menu")
            }.padding(16)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if results.isEmpty { Text("No matching applications").foregroundStyle(.secondary).padding(12) }
                        let groups = groupedResults
                        ForEach(groups.keys.sorted(), id: \.self) { letter in
                            Text(letter).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 10).padding(.horizontal, 10)
                            ForEach(groups[letter] ?? []) { app in
                                appRow(app)
                            }
                        }
                    }.padding(8)
                }.frame(width: 260)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pinned apps").font(.headline)
                        if pinned.isEmpty {
                            Text("Right-click an app to keep it here.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62))], spacing: 12) {
                                ForEach(pinned) { app in
                                    Button { open(app) } label: {
                                        VStack(spacing: 5) {
                                            Image(nsImage: AppIcons.icon(path: app.url.path)).resizable().frame(width: 32, height: 32)
                                            Text(app.name).font(.caption).lineLimit(1)
                                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityLabel("Launch \(app.name)")
                                        .contextMenu { Button("Unpin \(app.name)") { settings.togglePin(path: app.url.path) } }
                                }
                            }
                        }
                        Divider()
                        Text("Recent apps").font(.headline)
                        if launcher.recentApplications.isEmpty {
                            Text("Apps you use this session appear here.").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(launcher.recentApplications.prefix(8)) { app in appRow(app) }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(width: 240)
            }
            Divider()
            HStack {
                Text(launcher.lastLaunchMessage ?? "TaskPane · akashmahedy").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button("Refresh apps") { launcher.refresh() }.buttonStyle(.plain).font(.caption)
            }.padding(12)
        }.frame(width: 501, height: height)
            .tint(Color(taskPaneHex: settings.preferences.accentHex))
            .onAppear { presentationID = UUID(); launchRequest = nil; searchFocused = true }
            .onDisappear { presentationID = UUID(); launchRequest = nil }
            .onExitCommand(perform: dismiss)
            .accessibilityLabel("TaskPane Start menu")
    }

    private func appRow(_ app: LauncherEntry) -> some View {
        Button { open(app) } label: {
            HStack(spacing: 9) {
                Image(nsImage: AppIcons.icon(path: app.url.path)).resizable().frame(width: 23, height: 23)
                Text(app.name).font(.system(size: 12)).lineLimit(1)
                Spacer(minLength: 2)
            }.padding(7).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Launch \(app.name)")
            .contextMenu {
                Button(settings.preferences.pinnedApplicationPaths.contains(app.url.path) ? "Unpin app" : "Keep in taskbar") {
                    settings.togglePin(path: app.url.path)
                }
            }
    }

    private func open(_ app: LauncherEntry) {
        let presentation = presentationID
        let request = UUID()
        launchRequest = request
        launcher.launch(app) { succeeded in
            guard presentationID == presentation, launchRequest == request else { return }
            launchRequest = nil
            if succeeded { dismiss() }
        }
    }
}
