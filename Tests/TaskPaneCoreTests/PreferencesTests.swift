import Foundation
import Testing
@testable import TaskPaneCore

struct PreferencesTests {
    @Test func everyPresetRoundTripsAllPreferences() throws {
        for preset in BuiltInPreset.allCases {
            let expected = preset.preferences
            try expected.validate()
            let data = try PreferencesBackup.encode(expected)
            let actual = try PreferencesBackup.decode(data)
            #expect(actual == expected, "Preset: \(preset.rawValue)")
        }
    }

    @Test func customSettingsRoundTripWithoutReordering() throws {
        var expected = TaskPanePreferences()
        expected.barEdge = .left
        expected.theme = .dark
        expected.accentHex = "aBcD12"
        expected.pinnedApplicationPaths = ["/Applications/Safari.app", "/Applications/TaskPane.app"]
        expected.excludedBundleIdentifiers = ["com.apple.finder", "com.example.Editor"]
        expected.widgets.reverse()
        expected.widgets[0].placement = .both
        let cpuIndex = try #require(expected.widgets.firstIndex { $0.kind == .cpu })
        expected.widgets[cpuIndex].style = .graph
        let actual = try PreferencesBackup.decode(PreferencesBackup.encode(expected))
        #expect(actual == expected)
    }

    @Test func rejectsNonFiniteAndOutOfRangeNumbers() {
        let invalidValues: [Double] = [.nan, .infinity, -.infinity, 31, 121]
        for value in invalidValues {
            var preferences = TaskPanePreferences()
            preferences.barHeight = value
            #expect(throws: (any Error).self) { try preferences.validate() }
            #expect(throws: (any Error).self) { try PreferencesBackup.encode(preferences) }
        }
        var preferences = TaskPanePreferences()
        preferences.refreshInterval = 0
        #expect(throws: (any Error).self) { try preferences.validate() }
        preferences = TaskPanePreferences()
        preferences.barOpacity = 1.1
        #expect(throws: (any Error).self) { try preferences.validate() }
    }

    @Test func rejectsFutureEnvelopeAndPreferencesVersions() throws {
        let valid = try PreferencesBackup.encode(TaskPanePreferences())
        let futureEnvelope = try modified(valid) { $0["schemaVersion"] = 2 }
        #expect(throws: PreferencesError.unsupportedSchemaVersion(2)) {
            try PreferencesBackup.decode(futureEnvelope)
        }
        let futurePreferences = try modified(valid) { envelope in
            var preferences = envelope["preferences"] as! [String: Any]
            preferences["schemaVersion"] = 2
            envelope["preferences"] = preferences
        }
        #expect(throws: PreferencesError.unsupportedSchemaVersion(2)) {
            try PreferencesBackup.decode(futurePreferences)
        }
    }

    @Test func rejectsDuplicateOrMissingWidgets() throws {
        var preferences = TaskPanePreferences()
        preferences.widgets[1].kind = .cpu
        #expect(throws: (any Error).self) { try preferences.validate() }
        let valid = try PreferencesBackup.encode(TaskPanePreferences())
        let duplicate = try modified(valid) { envelope in
            var preferences = envelope["preferences"] as! [String: Any]
            var widgets = preferences["widgets"] as! [[String: Any]]
            widgets[1] = widgets[0]
            preferences["widgets"] = widgets
            envelope["preferences"] = preferences
        }
        #expect(throws: (any Error).self) { try PreferencesBackup.decode(duplicate) }
        preferences = TaskPanePreferences()
        preferences.widgets.removeLast()
        #expect(throws: (any Error).self) { try preferences.validate() }
    }

    @Test func rejectsOversizedMalformedAndForeignBackups() throws {
        #expect(throws: PreferencesError.backupTooLarge) {
            try PreferencesBackup.decode(Data(repeating: 32, count: PreferencesBackup.maximumDataSize + 1))
        }
        #expect(throws: PreferencesError.malformedBackup) {
            try PreferencesBackup.decode(Data("not JSON".utf8))
        }
        let valid = try PreferencesBackup.encode(TaskPanePreferences())
        let foreign = try modified(valid) { $0["format"] = "AnotherApp.preferences" }
        #expect(throws: PreferencesError.unsupportedFormat) { try PreferencesBackup.decode(foreign) }
    }

    @Test func rejectsInvalidImportedRangesAndDate() throws {
        let valid = try PreferencesBackup.encode(TaskPanePreferences())
        let invalidRange = try modified(valid) { envelope in
            var preferences = envelope["preferences"] as! [String: Any]
            preferences["iconSize"] = 1000
            envelope["preferences"] = preferences
        }
        #expect(throws: (any Error).self) { try PreferencesBackup.decode(invalidRange) }
        let invalidDate = try modified(valid) { $0["exportedAtISODate"] = "yesterday" }
        #expect(throws: PreferencesError.malformedBackup) { try PreferencesBackup.decode(invalidDate) }
    }

    @Test func rejectsCommandsScriptsRelativePathsAndDuplicatePins() {
        for invalidPath in ["Safari.app", "https://example.com/Tool.app", "/tmp/run.sh", "/Applications/Foo.app\n", "/Applications/../Applications/Safari.app"] {
            var preferences = TaskPanePreferences()
            preferences.pinnedApplicationPaths = [invalidPath]
            #expect(throws: (any Error).self) { try preferences.validate() }
        }
        var preferences = TaskPanePreferences()
        preferences.pinnedApplicationPaths = ["/Applications/Safari.app", "/Applications/Safari.app"]
        #expect(throws: (any Error).self) { try preferences.validate() }
        preferences.pinnedApplicationPaths = ["/Applications/Safari.app", "/Applications//Safari.app"]
        #expect(throws: (any Error).self) { try preferences.validate() }
    }

    @Test func widgetPlacementDestinations() {
        #expect(!WidgetPlacement.off.showsInTaskbar)
        #expect(!WidgetPlacement.off.showsInMenubar)
        #expect(WidgetPlacement.taskbar.showsInTaskbar)
        #expect(!WidgetPlacement.taskbar.showsInMenubar)
        #expect(!WidgetPlacement.menubar.showsInTaskbar)
        #expect(WidgetPlacement.menubar.showsInMenubar)
        #expect(WidgetPlacement.both.showsInTaskbar)
        #expect(WidgetPlacement.both.showsInMenubar)
    }

    @Test func oldSchemaOneBackupUsesDefaultLayout() throws {
        var previous = TaskPanePreferences()
        previous.appMode = .taskbar
        previous.pinnedApplicationPaths = ["/Applications/Safari.app"]
        previous.layout.lengthPercent = 64
        let data = try modified(PreferencesBackup.encode(previous)) { envelope in
            var preferences = envelope["preferences"] as! [String: Any]
            preferences.removeValue(forKey: "customization")
            envelope["preferences"] = preferences
        }
        let actual = try PreferencesBackup.decode(data)
        #expect(actual.customization == nil)
        #expect(actual.layout == LayoutCustomization())
        #expect(actual.appMode == .taskbar)
        #expect(actual.pinnedApplicationPaths == previous.pinnedApplicationPaths)
    }

    @Test func customizedLayoutRoundTripsEveryField() throws {
        var expected = TaskPanePreferences()
        var layout = LayoutCustomization()
        layout.alignment = .trailing
        layout.lengthPercent = 76
        layout.edgeOffset = 42
        layout.alongEdgeOffset = -120
        layout.itemSizing = .fixed
        layout.itemWidth = 180
        layout.minItemWidth = 100
        layout.maxItemWidth = 320
        layout.itemHeight = 48
        layout.itemSpacing = 12
        layout.itemOpacity = 0.35
        layout.itemCornerRadius = 14
        layout.barCornerRadius = 24
        layout.autoArrange = false
        layout.sortOrder = .recent
        layout.applicationOrder = ["com.example.Editor", "com.apple.Safari"]
        layout.sectionOrder.reverse()
        layout.showDividers = false
        layout.showActiveIndicator = false
        layout.showMinimizedWindows = false
        layout.showOffscreenWindows = true
        layout.showDialogs = true
        expected.layout = layout
        let actual = try PreferencesBackup.decode(PreferencesBackup.encode(expected))
        #expect(actual == expected)
        #expect(actual.layout == layout)
    }

    @Test func rejectsInvalidLayoutNumbersAndAcceptsBoundaries() throws {
        let ranges: [(WritableKeyPath<LayoutCustomization, Double>, Double, Double)] = [
            (\.lengthPercent, 40, 100), (\.edgeOffset, 0, 200), (\.alongEdgeOffset, -500, 500),
            (\.itemWidth, 48, 420), (\.minItemWidth, 48, 420), (\.maxItemWidth, 48, 420),
            (\.itemHeight, 24, 100), (\.itemSpacing, 0, 30), (\.itemOpacity, 0, 1),
            (\.itemCornerRadius, 0, 50), (\.barCornerRadius, 0, 60)
        ]
        for (keyPath, lower, upper) in ranges {
            for value in [lower, upper] {
                var layout = LayoutCustomization()
                layout.minItemWidth = 48
                layout.maxItemWidth = 420
                layout[keyPath: keyPath] = value
                try layout.validate()
            }
            for value in [lower - 1, upper + 1, .nan, .infinity, -.infinity] {
                var preferences = TaskPanePreferences()
                preferences.layout[keyPath: keyPath] = value
                #expect(throws: (any Error).self) { try preferences.validate() }
                #expect(throws: (any Error).self) { try PreferencesBackup.encode(preferences) }
            }
        }
        var preferences = TaskPanePreferences()
        preferences.layout.minItemWidth = 300
        preferences.layout.maxItemWidth = 200
        #expect(throws: (any Error).self) { try preferences.validate() }

        let valid = try PreferencesBackup.encode(BuiltInPreset.balanced.preferences)
        let invalidImportedLayout = try modified(valid) { envelope in
            var preferences = envelope["preferences"] as! [String: Any]
            var layout = preferences["customization"] as! [String: Any]
            layout["alongEdgeOffset"] = -501
            preferences["customization"] = layout
            envelope["preferences"] = preferences
        }
        #expect(throws: (any Error).self) { try PreferencesBackup.decode(invalidImportedLayout) }
    }

    @Test func rejectsMissingDuplicateSectionsAndInvalidApplicationOrder() throws {
        var preferences = TaskPanePreferences()
        preferences.layout.sectionOrder.removeLast()
        #expect(throws: (any Error).self) { try preferences.validate() }
        preferences = TaskPanePreferences()
        preferences.layout.sectionOrder[1] = .launcher
        #expect(throws: (any Error).self) { try preferences.validate() }
        for invalid in [[""], ["  "], [String(repeating: "a", count: 256)], ["com.example.app", "com.example.app"]] {
            preferences = TaskPanePreferences()
            preferences.layout.applicationOrder = invalid
            #expect(throws: (any Error).self) { try preferences.validate() }
        }
        preferences = TaskPanePreferences()
        preferences.layout.applicationOrder = (0..<200).map { "com.example.app\($0)" }
        try preferences.validate()
        preferences.layout.applicationOrder.append("com.example.app200")
        #expect(throws: (any Error).self) { try preferences.validate() }
    }

    @Test func presetsHaveDistinctFunctionalLayouts() throws {
        let presets = BuiltInPreset.allCases.map(\.preferences)
        for first in presets.indices {
            for second in presets.indices where second > first {
                #expect(presets[first].layout != presets[second].layout)
            }
        }
        let windows = BuiltInPreset.windows.preferences
        #expect(windows.layout.lengthPercent == 100)
        #expect(windows.layout.itemSizing == .fixed)
        #expect(windows.showWindowTitles)
        let balanced = BuiltInPreset.balanced.preferences
        #expect(balanced.widgets.filter { $0.kind.supportsGraph }.allSatisfy { $0.style == .graph })
        let compact = BuiltInPreset.compact.preferences
        #expect(compact.layout.lengthPercent == 62)
        #expect(compact.layout.alignment == .center)
        #expect(compact.grouping == .adjacent && !compact.showWindowTitles && !compact.showAppNames)
        let monitoring = BuiltInPreset.monitoring.preferences
        #expect(monitoring.appMode == .menubar)
        #expect(monitoring.widgets.allSatisfy { $0.placement == .menubar })
        let focus = BuiltInPreset.focus.preferences
        #expect(focus.grouping == .adjacent)
        #expect(focus.autoHide && !focus.showWindowTitles && !focus.showAppNames)
        #expect(focus.barHeight < compact.barHeight)
        #expect(focus.layout.lengthPercent < compact.layout.lengthPercent)
        #expect(focus.widgets.allSatisfy { $0.placement == .off })
        for preset in presets {
            #expect(preset.widgets.allSatisfy { $0.style != .graph || $0.kind.supportsGraph })
        }
    }

    @Test func legacyUnsupportedGraphsImportAsNumbers() throws {
        var previous = TaskPanePreferences()
        for index in previous.widgets.indices {
            previous.widgets[index].style = .graph
        }
        let actual = try PreferencesBackup.decode(PreferencesBackup.encode(previous))
        for widget in actual.widgets {
            #expect(widget.style == (widget.kind.supportsGraph ? .graph : .number))
        }
        #expect(actual.widgets.map(\.placement) == previous.widgets.map(\.placement))
    }

    @Test func pinnedApplicationLimitAccepts100AndRejects101() throws {
        var preferences = TaskPanePreferences()
        preferences.pinnedApplicationPaths = (0..<100).map { "/Applications/TaskPaneFixture\($0).app" }
        try preferences.validate()
        #expect(try PreferencesBackup.decode(PreferencesBackup.encode(preferences)) == preferences)
        preferences.pinnedApplicationPaths.append("/Applications/TaskPaneFixture100.app")
        #expect(throws: (any Error).self) { try preferences.validate() }
        #expect(throws: (any Error).self) { try PreferencesBackup.encode(preferences) }
    }

    @Test func firstManualMoveUsesVisibleAutomaticOrder() throws {
        var layout = LayoutCustomization()
        layout.applicationOrder = ["A", "B", "C", "not-running"]
        layout.autoArrange = true
        let result = try #require(layout.movingApplication("A", before: "B", currentOrder: ["C", "B", "A"]))
        #expect(result.applicationOrder == ["C", "A", "B", "not-running"])
        #expect(!result.autoArrange)
        #expect(layout.applicationOrder == ["A", "B", "C", "not-running"])
    }

    @Test func manualMovesPreserveHiddenApplicationsAndDeduplicateKeys() throws {
        var layout = LayoutCustomization()
        layout.autoArrange = false
        layout.applicationOrder = ["A", "not-running", "B", "C"]
        let result = try #require(layout.movingApplication("C", before: "B", currentOrder: ["A", "B", "B", "C", "new"]))
        #expect(result.applicationOrder == ["A", "not-running", "C", "B", "new"])
        try result.validate()
    }

    @Test func directionalMovesMoveOnePositionAndRespectBoundaries() throws {
        let layout = LayoutCustomization()
        let up = try #require(layout.movingApplication("B", direction: -1, currentOrder: ["A", "B", "C"]))
        #expect(up.applicationOrder == ["B", "A", "C"])
        let down = try #require(layout.movingApplication("B", direction: 1, currentOrder: ["A", "B", "C"]))
        #expect(down.applicationOrder == ["A", "C", "B"])
        #expect(layout.movingApplication("A", direction: -1, currentOrder: ["A", "B", "C"]) == nil)
        #expect(layout.movingApplication("C", direction: 1, currentOrder: ["A", "B", "C"]) == nil)
        #expect(layout.movingApplication("missing", direction: 1, currentOrder: ["A", "B", "C"]) == nil)
        #expect(layout.movingApplication("B", direction: Int.max, currentOrder: ["A", "B", "C"]) == nil)
        #expect(layout.movingApplication("A", before: "A", currentOrder: ["A", "B"]) == nil)
    }

    @Test func manualApplicationOrderSurvivesBackupRoundTrip() throws {
        var preferences = BuiltInPreset.balanced.preferences
        preferences.layout = try #require(preferences.layout.movingApplication("C", direction: -1, currentOrder: ["A", "B", "C"]))
        let actual = try PreferencesBackup.decode(PreferencesBackup.encode(preferences))
        #expect(actual.layout.applicationOrder == ["A", "C", "B"])
        #expect(!actual.layout.autoArrange)
        #expect(actual == preferences)
    }

    @Test func legacyGroupingValuesKeepTheirSavedMeaning() throws {
        let valid = try PreferencesBackup.encode(BuiltInPreset.compact.preferences)
        for (raw, expected) in [("never", GroupingMode.never), ("always", .always), ("automatic", .automatic)] {
            let legacy = try modified(valid) { envelope in
                var preferences = envelope["preferences"] as! [String: Any]
                preferences["grouping"] = raw
                envelope["preferences"] = preferences
            }
            let restored = try PreferencesBackup.decode(legacy)
            #expect(restored.grouping == expected)
            #expect(!restored.showWindowTitles)
            #expect(restored.layout == BuiltInPreset.compact.preferences.layout)
        }
    }

    @Test func adjacentGroupingPreservesCustomizationInBackup() throws {
        var preferences = BuiltInPreset.balanced.preferences
        preferences.grouping = .adjacent
        preferences.layout.applicationOrder = ["com.example.Editor", "com.apple.Safari"]
        preferences.layout.autoArrange = false
        preferences.layout.sectionOrder.reverse()
        preferences.pinnedApplicationPaths = ["/Applications/Safari.app"]
        preferences.excludedBundleIdentifiers = ["com.example.Hidden"]
        #expect(try PreferencesBackup.decode(PreferencesBackup.encode(preferences)) == preferences)
    }

    @Test func classicBehaviorPreservesTheRestOfTheSetup() throws {
        var original = BuiltInPreset.compact.preferences
        original.grouping = .always
        original.showWindowTitles = false
        original.secondClickMinimizes = false
        original.currentDisplayOnly = true
        original.autoHide = true
        original.theme = .dark
        original.barEdge = .left
        original.accentHex = "15aB72"
        original.layout.autoArrange = true
        original.layout.showMinimizedWindows = false
        original.layout.showOffscreenWindows = false
        original.layout.showDialogs = true
        original.layout.applicationOrder = ["com.apple.Safari", "com.example.Editor"]
        original.layout.sectionOrder.reverse()
        original.layout.alongEdgeOffset = 123
        original.pinnedApplicationPaths = ["/Applications/Safari.app"]
        original.excludedBundleIdentifiers = ["com.example.Hidden"]
        original.widgets.reverse()

        var expected = original
        expected.grouping = .adjacent
        expected.showWindowTitles = true
        expected.secondClickMinimizes = true
        expected.currentDisplayOnly = false
        expected.layout.autoArrange = false
        expected.layout.showMinimizedWindows = true
        expected.layout.showOffscreenWindows = true
        let actual = original.usingTaskbarBehavior()
        #expect(actual == expected)
        #expect(original.grouping == .always)
        #expect(actual.usingTaskbarBehavior() == actual)
        #expect(try PreferencesBackup.decode(PreferencesBackup.encode(actual)) == actual)
    }

    private func modified(_ data: Data, change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
