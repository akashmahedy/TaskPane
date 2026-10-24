import Foundation
import Testing
@testable import TaskPaneCore

struct DockPreferencesTests {
    @Test func hiddenDockRestoresAbsentAndExplicitValues() {
        let original = DockPreferenceValues(orientation: "bottom", autoHide: false)
        let applied = DockPreferenceValues(orientation: "left", autoHide: true, revealDelay: DockPreferenceValues.suppressedRevealDelay)
        #expect(applied.fullyHidden)
        #expect(applied.restoring(original: original, applied: applied) == original)
        #expect(applied.restoring(original: .init(), applied: applied) == .init())
    }
    @Test func turningFullHidingOffRemovesAnOriginallyAbsentDelay() {
        let original = DockPreferenceValues(orientation: "bottom", autoHide: false)
        let hidden = original.applying(orientation: "left", autoHide: false, fullyHidden: true, original: nil)
        #expect(hidden.fullyHidden)
        let normal = hidden.applying(orientation: "left", autoHide: true, fullyHidden: false, original: original)
        #expect(normal.revealDelay == nil)
        #expect(!normal.fullyHidden)
    }
    @Test func recoveryPreservesIndependentDockEdits() {
        let original = DockPreferenceValues(orientation: "bottom", autoHide: false, revealDelay: 0.4)
        let applied = DockPreferenceValues(orientation: "left", autoHide: true, revealDelay: DockPreferenceValues.suppressedRevealDelay)
        var current = applied
        current.orientation = "right"
        #expect(current.restoring(original: original, applied: applied) == .init(orientation: "right", autoHide: false, revealDelay: 0.4))
        current.revealDelay = 0.9
        #expect(current.restoring(original: original, applied: applied).revealDelay == 0.9)
    }
    @Test func olderDockSnapshotsDecodeWithoutInventingDelay() throws {
        let values = try JSONDecoder().decode(DockPreferenceValues.self, from: Data(#"{"orientation":"left","autoHide":true}"#.utf8))
        #expect(values.revealDelay == nil)
        #expect(!values.fullyHidden)
        #expect(!DockPreferenceValues(revealDelay: .infinity).isValid)
        #expect(!DockPreferenceValues(revealDelay: -1).isValid)
    }
    @Test func tabOptionAndThemeColorsSurviveBackup() throws {
        var preferences = BuiltInPreset.rosePine.preferences
        preferences.options.showStandardTabs = false
        #expect(try PreferencesBackup.decode(PreferencesBackup.encode(preferences)) == preferences)
        let legacy = try JSONDecoder().decode(TaskbarAdvancedOptions.self, from: Data("{}".utf8))
        #expect(legacy.showStandardTabs)
        #expect(legacy.barBackgroundHex == nil)
        preferences.options.barBackgroundHex = "bogus"
        #expect(throws: (any Error).self) { try preferences.validate() }
    }
}
