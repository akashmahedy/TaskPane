import AppKit
import Combine
import CoreFoundation
import Darwin
import Foundation
import TaskPaneCore

enum DockEdge: String, Codable, CaseIterable, Identifiable {
    case bottom, left, right
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct DockConfiguration: Equatable {
    var edge: DockEdge
    var autoHide: Bool
    var fullyHidden: Bool = false
}

/// Dock changes happen only after an explicit Apply or Restore action. The local
/// snapshot tracks key presence so restoring can remove keys that were absent.
@MainActor
final class DockIntegrationService: ObservableObject {
    static let shared = DockIntegrationService()
    @Published private(set) var current = DockConfiguration(edge: .bottom, autoHide: false)
    @Published private(set) var hasBackup = false
    @Published private(set) var canRestore = false
    @Published private(set) var originalDescription: String?
    @Published private(set) var notice: String?
    @Published private(set) var error: String?

    private typealias StoredValues = DockPreferenceValues
    private struct Snapshot: Codable {
        var version = 2
        var original: StoredValues
        var applied: StoredValues
        var restoreWhenQuitting: Bool?
    }
    @Published private(set) var restoreWhenQuitting = true
    private let domain = "com.apple.dock" as CFString
    private let snapshotURL: URL
    private var snapshot: Snapshot?

    init() {
        let arguments = CommandLine.arguments
        let directory: URL
        if let index = arguments.firstIndex(of: "--data-dir"), arguments.indices.contains(index + 1) {
            directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TaskPane", isDirectory: true)
        }
        snapshotURL = directory.appendingPathComponent("Dock-original.json")
        if FileManager.default.fileExists(atPath: snapshotURL.path) {
            do {
                let data = try Data(contentsOf: snapshotURL)
                guard data.count < 16_384 else { throw DockError.message("The saved Dock backup is too large.") }
                let saved = try JSONDecoder().decode(Snapshot.self, from: data)
                guard (1...2).contains(saved.version), saved.original.isValid, saved.applied.isValid,
                      saved.applied.orientation.flatMap(DockEdge.init(rawValue:)) != nil,
                      saved.applied.autoHide != nil else {
                    throw DockError.message("The saved Dock backup has an unsupported format.")
                }
                var migrated = saved
                if saved.version == 1 {
                    // Older TaskPane managed only two keys. Never claim ownership
                    // of an existing reveal delay during legacy recovery.
                    let delay = try readValues().revealDelay
                    migrated.original.revealDelay = delay
                    migrated.applied.revealDelay = delay
                    migrated.version = 2
                }
                snapshot = migrated
                restoreWhenQuitting = migrated.restoreWhenQuitting ?? false
            } catch { self.error = "Could not read the saved Dock setup: \(error.localizedDescription)" }
        }
        refresh()
    }

    func refresh() {
        do {
            let values = try readValues()
            current = configuration(values)
            hasBackup = snapshot != nil || FileManager.default.fileExists(atPath: snapshotURL.path)
            canRestore = snapshot != nil
            originalDescription = snapshot.map { describe(configuration($0.original)) }
        } catch { self.error = error.localizedDescription }
    }

    func apply(_ proposed: DockConfiguration, restoreOnQuit: Bool = true) {
        error = nil; notice = nil
        do {
            let before = try readValues()
            if hasBackup && snapshot == nil {
                throw DockError.message("Keep the current Dock setup to clear the unreadable backup before applying another setup.")
            }
            if let snapshot, snapshot.applied != before {
                throw DockError.message("The Dock changed after TaskPane last adjusted it. Keep the current setup before applying another change.")
            }
            let applied = before.applying(orientation: proposed.edge.rawValue, autoHide: proposed.autoHide,
                                          fullyHidden: proposed.fullyHidden, original: snapshot?.original)
            let saved = Snapshot(original: snapshot?.original ?? before, applied: applied, restoreWhenQuitting: restoreOnQuit)
            try save(saved) // A failed backup save must not modify the Dock.
            snapshot = saved
            restoreWhenQuitting = restoreOnQuit
            try writeValues(applied)
            let restarted = try restartDock()
            notice = restarted ? "Dock settings applied. The Dock is restarting." : "Dock settings saved. They apply when the Dock next starts."
        } catch { self.error = error.localizedDescription }
        refresh()
    }

    func restore() {
        error = nil; notice = nil
        do {
            guard let saved = snapshot else { throw DockError.message("There is no readable Dock backup to restore.") }
            let current = try readValues()
            let restored = current.restoring(original: saved.original, applied: saved.applied)
            try writeValues(restored)
            // Record a completed restoration before restarting so a restart failure
            // cannot make the UI offer another destructive restoration.
            try FileManager.default.removeItem(at: snapshotURL)
            snapshot = nil
            let restarted = try restartDock()
            notice = restarted ? "Your original Dock settings were restored; any newer independent edits were kept. The Dock is restarting." : "Your original Dock settings were restored; any newer independent edits were kept. They apply when the Dock next starts."
        } catch { self.error = error.localizedDescription }
        refresh()
    }

    func restoreForTermination() {
        guard snapshot?.restoreWhenQuitting == true else { return }
        restore()
    }

    private func configuration(_ values: StoredValues) -> DockConfiguration {
        DockConfiguration(edge: values.orientation.flatMap(DockEdge.init(rawValue:)) ?? .bottom,
                          autoHide: values.autoHide ?? false, fullyHidden: values.fullyHidden)
    }

    /// Removes only TaskPane's local recovery file. It never writes Dock keys.
    func keepCurrentSetup() {
        error = nil; notice = nil
        do {
            if FileManager.default.fileExists(atPath: snapshotURL.path) { try FileManager.default.removeItem(at: snapshotURL) }
            snapshot = nil
            notice = "Current Dock settings kept. The old TaskPane Dock backup was cleared."
        } catch { self.error = "Could not clear the Dock backup: \(error.localizedDescription)" }
        refresh()
    }

    private func readValues() throws -> StoredValues {
        _ = CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let orientation = CFPreferencesCopyValue("orientation" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let autoHide = CFPreferencesCopyValue("autohide" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if let orientation, !(orientation is String) { throw DockError.message("The Dock orientation setting has an unsupported value.") }
        if let orientation = orientation as? String, DockEdge(rawValue: orientation) == nil { throw DockError.message("The Dock orientation setting has an unsupported value.") }
        if let autoHide, CFGetTypeID(autoHide) != CFBooleanGetTypeID() { throw DockError.message("The Dock auto-hide setting has an unsupported value.") }
        let delay = CFPreferencesCopyValue("autohide-delay" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if let delay, CFGetTypeID(delay) != CFNumberGetTypeID() { throw DockError.message("The Dock reveal delay has an unsupported value.") }
        let values = StoredValues(orientation: orientation as? String, autoHide: autoHide as? Bool,
                                  revealDelay: (delay as? NSNumber)?.doubleValue)
        guard values.isValid else { throw DockError.message("The Dock preferences contain unsupported values.") }
        return values
    }

    private func writeValues(_ values: StoredValues) throws {
        CFPreferencesSetValue("orientation" as CFString, values.orientation.map { $0 as CFString }, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let autoHide: CFBoolean? = values.autoHide.map { $0 ? kCFBooleanTrue : kCFBooleanFalse }
        CFPreferencesSetValue("autohide" as CFString, autoHide, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSetValue("autohide-delay" as CFString, values.revealDelay.map { NSNumber(value: $0) }, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw DockError.message("The Dock preferences could not be saved. The local recovery backup was kept.")
        }
        guard try readValues() == values else {
            throw DockError.message("The Dock did not retain the requested settings. The local recovery backup was kept.")
        }
    }

    private func save(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: snapshotURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshotURL.path)
    }

    private func restartDock() throws -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
        var restarted = false
        for app in apps where !app.isTerminated && app.processIdentifier > 1 {
            guard NSRunningApplication(processIdentifier: app.processIdentifier)?.bundleIdentifier == "com.apple.dock" else { continue }
            guard Darwin.kill(app.processIdentifier, SIGTERM) == 0 else {
                throw DockError.message("Dock settings were saved, but the Dock could not restart. Log out and back in to apply them.")
            }
            restarted = true
        }
        return restarted
    }

    private func describe(_ values: DockConfiguration) -> String {
        "\(values.edge.title), \(values.fullyHidden ? "fully hidden" : values.autoHide ? "auto-hide on" : "auto-hide off")"
    }
    private enum DockError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
    }
}
