import AppKit
import Combine

struct LauncherEntry: Identifiable {
    var id: String { url.path }
    let name: String
    let url: URL
    let bundleIdentifier: String?
}

@MainActor
final class LauncherService: ObservableObject {
    @Published var applications: [LauncherEntry] = []
    @Published private(set) var lastLaunchMessage: String?

    private let worker = DispatchQueue(label: "app.taskpane.application-index", qos: .utility)
    private var refreshing = false
    private var refreshRequested = false

    init() { refresh() }

    func refresh() {
        if refreshing {
            refreshRequested = true
            return
        }
        refreshing = true
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        worker.async { [weak self] in
            let applications = ApplicationIndexer.applications(in: roots)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.applications = applications
                self.refreshing = false
                if self.refreshRequested {
                    self.refreshRequested = false
                    self.refresh()
                }
            }
        }
    }

    func launch(_ entry: LauncherEntry) {
        var isDirectory: ObjCBool = false
        guard entry.url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: entry.url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            lastLaunchMessage = "This application is no longer installed. Refresh the app list."
            return
        }
        lastLaunchMessage = nil
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: entry.url, configuration: configuration) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.lastLaunchMessage = "Could not open \(entry.name): \(error.localizedDescription)"
            }
        }
    }
}

private enum ApplicationIndexer {
    static func applications(in roots: [URL]) -> [LauncherEntry] {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        var seen = Set<String>()
        var entries: [LauncherEntry] = []
        var inspected = 0
        let deadline = ProcessInfo.processInfo.systemUptime + 4

        for root in roots {
            guard let enumerator = manager.enumerator(
                at: root, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            while let url = enumerator.nextObject() as? URL {
                inspected += 1
                guard inspected <= 12_000, entries.count < 4_000,
                      ProcessInfo.processInfo.systemUptime < deadline else { break }
                let isApplication = url.pathExtension.caseInsensitiveCompare("app") == .orderedSame
                if isApplication { enumerator.skipDescendants() }
                if enumerator.level > 4 {
                    enumerator.skipDescendants()
                    continue
                }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                if values.isSymbolicLink == true && !isApplication {
                    enumerator.skipDescendants()
                    continue
                }
                guard isApplication else { continue }
                let bundleURL = url.resolvingSymlinksInPath().standardizedFileURL
                var isDirectory: ObjCBool = false
                guard manager.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory),
                      isDirectory.boolValue, seen.insert(bundleURL.path).inserted else { continue }
                let bundle = Bundle(url: bundleURL)
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? bundleURL.deletingPathExtension().lastPathComponent
                entries.append(LauncherEntry(name: name, url: bundleURL, bundleIdentifier: bundle?.bundleIdentifier))
            }
        }
        return entries.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
}
