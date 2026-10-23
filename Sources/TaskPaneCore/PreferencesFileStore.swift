import Foundation

/// Filesystem persistence separate from UI so failed imports cannot commit UI state.
public struct PreferencesFileStore {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> TaskPanePreferences? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= PreferencesBackup.maximumDataSize else { throw PreferencesError.backupTooLarge }
        return try PreferencesBackup.decode(Data(contentsOf: url))
    }

    public func save(_ preferences: TaskPanePreferences, preservingUnreadableOriginal: Bool = false) throws {
        let data = try PreferencesBackup.encode(preferences)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            do { _ = try load() }
            catch {
                guard preservingUnreadableOriginal else { throw PreferencesFileError.unreadableOriginal }
                let backup = url.deletingLastPathComponent().appendingPathComponent("preferences-unreadable-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: url, to: backup)
            }
        }
        try data.write(to: url, options: .atomic)
    }
}

public enum PreferencesFileError: Error, LocalizedError {
    case unreadableOriginal
    public var errorDescription: String? {
        "The saved preferences file could not be read and has been preserved. Import a valid backup to restore your setup, or export your current settings as a separate file."
    }
}
