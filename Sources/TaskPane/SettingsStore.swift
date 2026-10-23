import AppKit
import Combine
import Foundation
import TaskPaneCore
import UniformTypeIdentifiers

@MainActor
final class SettingsStore: ObservableObject {
    @Published var preferences: TaskPanePreferences {
        didSet {
            guard preferences != oldValue else { return }
            activePreset = nil
            scheduleSave()
        }
    }
    @Published private(set) var activePreset: String?
    @Published var notice: String?
    @Published var errorMessage: String?
    private var pendingSave: DispatchWorkItem?
    private let preferencesURL: URL
    private let fileStore: PreferencesFileStore

    init() {
        let arguments = CommandLine.arguments
        let dataDirectory: URL
        if let index = arguments.firstIndex(of: "--data-dir"), arguments.indices.contains(index + 1) {
            dataDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else {
            dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TaskPane", isDirectory: true)
        }
        preferencesURL = dataDirectory.appendingPathComponent("preferences.json")
        fileStore = PreferencesFileStore(url: preferencesURL)
        preferences = BuiltInPreset.windows.preferences
        if FileManager.default.fileExists(atPath: preferencesURL.path) {
            do {
                preferences = try fileStore.load() ?? TaskPanePreferences()
            } catch {
                errorMessage = "Your saved settings could not be read. The original file has been preserved. \(error.localizedDescription)"
            }
        }
    }

    var storagePath: String { preferencesURL.deletingLastPathComponent().path }

    func apply(_ preset: BuiltInPreset) {
        var updated = preset.preferences
        updated.pinnedApplicationPaths = preferences.pinnedApplicationPaths
        updated.excludedBundleIdentifiers = preferences.excludedBundleIdentifiers
        preferences = updated
        activePreset = preset.rawValue
        notice = "\(preset.displayName) applied. Your pins and excluded apps were kept."
    }

    @discardableResult func saveNow() -> Bool {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try fileStore.save(preferences)
            return true
        } catch {
            errorMessage = "Could not save settings: \(error.localizedDescription)"
            return false
        }
    }

    func exportPreferences() {
        let panel = NSSavePanel()
        panel.title = "Export TaskPane preferences"
        panel.nameFieldStringValue = "TaskPane-preferences.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PreferencesBackup.encode(preferences)
            try data.write(to: url, options: .atomic)
            notice = "Preferences exported. Keep this file to restore your setup on another Mac."
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func importPreferences() {
        let panel = NSOpenPanel()
        panel.title = "Import TaskPane preferences"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 1_048_576 else { throw ImportError.tooLarge }
            let imported = try PreferencesBackup.decode(Data(contentsOf: url))
            // Validate the whole file before changing the current setup.
            let alert = NSAlert()
            alert.messageText = "Replace your current setup?"
            alert.informativeText = "The selected preferences are valid. Import replaces your appearance, widgets, pins and display settings. Export the current setup first if you want to keep it."
            alert.addButton(withTitle: "Import preferences")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            // Persist first: a failed write must leave the in-memory setup unchanged.
            try fileStore.save(imported, preservingUnreadableOriginal: true)
            preferences = imported
            notice = "Preferences imported successfully."
        } catch {
            errorMessage = "Import failed. Your current setup is unchanged. \(error.localizedDescription)"
        }
    }

    func addPinnedApplication() {
        let panel = NSOpenPanel()
        panel.title = "Pin an application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK else { return }
        var candidate = preferences
        for url in panel.urls where !candidate.pinnedApplicationPaths.contains(url.path) { candidate.pinnedApplicationPaths.append(url.path) }
        accept(candidate)
    }

    func togglePin(path: String) {
        var candidate = preferences
        if candidate.pinnedApplicationPaths.contains(path) {
            candidate.pinnedApplicationPaths.removeAll { $0 == path }
        } else {
            candidate.pinnedApplicationPaths.append(path)
        }
        accept(candidate)
    }

    func excludeApplication(_ identifier: String) {
        var candidate = preferences
        guard !candidate.excludedBundleIdentifiers.contains(identifier) else { return }
        candidate.excludedBundleIdentifiers.append(identifier)
        accept(candidate)
    }

    func moveSection(_ section: BarSection, direction: Int) {
        var candidate = preferences
        guard let index = candidate.layout.sectionOrder.firstIndex(of: section),
              candidate.layout.sectionOrder.indices.contains(index + direction) else { return }
        candidate.layout.sectionOrder.swapAt(index, index + direction)
        accept(candidate)
    }

    func moveApplication(_ key: String, before target: String, currentOrder: [String]) {
        var candidate = preferences
        guard let updated = candidate.layout.movingApplication(key, before: target, currentOrder: currentOrder) else { return }
        candidate.layout = updated
        accept(candidate)
    }

    func moveApplication(_ key: String, direction: Int, currentOrder: [String]) {
        var candidate = preferences
        guard let updated = candidate.layout.movingApplication(key, direction: direction, currentOrder: currentOrder) else { return }
        candidate.layout = updated
        accept(candidate)
    }

    private func accept(_ candidate: TaskPanePreferences) {
        do { try candidate.validate(); preferences = candidate }
        catch { errorMessage = error.localizedDescription }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private enum ImportError: LocalizedError {
        case tooLarge
        var errorDescription: String? { "Preference files must be 1 MiB or smaller." }
    }
}
