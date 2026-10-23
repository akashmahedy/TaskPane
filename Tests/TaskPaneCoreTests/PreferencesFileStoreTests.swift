import Foundation
import Testing
@testable import TaskPaneCore

@Suite struct PreferencesFileStoreTests {
    private func temporaryDirectory() throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPane-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    @Test func savesAndReloadsPreset() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PreferencesFileStore(url: directory.appendingPathComponent("preferences.json"))
        #expect(try store.load() == nil)
        try store.save(BuiltInPreset.compact.preferences)
        #expect(try store.load() == BuiltInPreset.compact.preferences)
    }

    @Test func corruptOriginalIsPreservedUntilExplicitImport() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("preferences.json")
        let original = Data("{broken".utf8)
        try original.write(to: path)
        let store = PreferencesFileStore(url: path)
        #expect(throws: (any Error).self) { try store.save(TaskPanePreferences()) }
        #expect(try Data(contentsOf: path) == original)
        try store.save(BuiltInPreset.monitoring.preferences, preservingUnreadableOriginal: true)
        #expect(try store.load() == BuiltInPreset.monitoring.preferences)
        let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("preferences-unreadable-") }
        #expect(preserved.count == 1)
        #expect(try Data(contentsOf: #require(preserved.first)) == original)
    }

    @Test func failedDestinationThrowsInsteadOfReportingSuccess() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let obstacle = directory.appendingPathComponent("not-a-directory")
        try Data("original".utf8).write(to: obstacle)
        let store = PreferencesFileStore(url: obstacle.appendingPathComponent("preferences.json"))
        #expect(throws: (any Error).self) { try store.save(TaskPanePreferences()) }
        #expect(try String(contentsOf: obstacle, encoding: .utf8) == "original")
    }

    @Test func invalidCandidateNeverReplacesSavedPreferences() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("preferences.json")
        let store = PreferencesFileStore(url: path)
        try store.save(BuiltInPreset.balanced.preferences)
        let before = try Data(contentsOf: path)
        var invalid = TaskPanePreferences(); invalid.barHeight = -1
        #expect(throws: (any Error).self) { try store.save(invalid) }
        #expect(try Data(contentsOf: path) == before)
    }
}
