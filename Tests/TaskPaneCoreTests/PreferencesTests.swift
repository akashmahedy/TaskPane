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
        let invalidValues: [Double] = [.nan, .infinity, -.infinity, 23, 257]
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
            (\.lengthPercent, 10, 100), (\.edgeOffset, 0, 1000), (\.alongEdgeOffset, -4000, 4000),
            (\.itemWidth, 24, 1200), (\.minItemWidth, 24, 1200), (\.maxItemWidth, 24, 1200),
            (\.itemHeight, 20, 240), (\.itemSpacing, 0, 100), (\.itemOpacity, 0, 1),
            (\.itemCornerRadius, 0, 128), (\.barCornerRadius, 0, 128)
        ]
        for (keyPath, lower, upper) in ranges {
            for value in [lower, upper] {
                var layout = LayoutCustomization()
                layout.minItemWidth = 24
                layout.maxItemWidth = 1200
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
            layout["alongEdgeOffset"] = -4001
            preferences["customization"] = layout
            envelope["preferences"] = preferences
        }
        #expect(throws: (any Error).self) { try PreferencesBackup.decode(invalidImportedLayout) }
    }

    @Test func unifiedScaleKeepsSmallestAndLargestSetupsValid() throws {
        var original = BuiltInPreset.windows.preferences
        original.pinnedApplicationPaths = ["/Applications/Safari.app"]
        original.excludedBundleIdentifiers = ["com.example.Hidden"]
        original.options.middleClickClosesWindow = true
        original.options.startMenuWidth = 700
        let small = original.usingOverallScale(50)
        let large = original.usingOverallScale(250)
        try small.validate(); try large.validate()
        #expect(small.fontSize == 8) // Text stays readable at the supported minimum.
        #expect(large.layout.itemHeight > small.layout.itemHeight)
        #expect(large.iconSize > small.iconSize)
        #expect(large.options.verticalPadding > small.options.verticalPadding)
        for scaled in [small, large] {
            #expect(scaled.pinnedApplicationPaths == original.pinnedApplicationPaths)
            #expect(scaled.excludedBundleIdentifiers == original.excludedBundleIdentifiers)
            #expect(scaled.options.middleClickClosesWindow)
            #expect(scaled.options.startMenuWidth == 700)
            #expect(try PreferencesBackup.decode(PreferencesBackup.encode(scaled)) == scaled)
        }
        #expect(original.usingOverallScale(.nan) == original)
        #expect(original.usingOverallScale(0) == small)
        #expect(original.usingOverallScale(500) == large)
    }

    @Test func expandedAppearanceBoundariesRoundTrip() throws {
        let ranges: [(WritableKeyPath<TaskPanePreferences, Double>, Double, Double)] = [
            (\.barHeight, 24, 256), (\.barOpacity, 0, 1),
            (\.iconSize, 8, 128), (\.fontSize, 8, 48)
        ]
        for (key, lower, upper) in ranges {
            for value in [lower, upper] {
                var preferences = TaskPanePreferences()
                preferences[keyPath: key] = value
                #expect(try PreferencesBackup.decode(PreferencesBackup.encode(preferences)) == preferences)
            }
            for value in [lower - 0.01, upper + 0.01, .nan, .infinity, -.infinity] {
                var preferences = TaskPanePreferences()
                preferences[keyPath: key] = value
                #expect(throws: (any Error).self) { try preferences.validate() }
            }
        }
    }

    @Test func oldBackupsRetainPreferencesAndDefaultNewOptions() throws {
        var original = BuiltInPreset.windows.preferences
        original.layout.itemWidth = 203
        original.pinnedApplicationPaths = ["/Applications/Safari.app"]
        let oldBackup = try modified(PreferencesBackup.encode(original)) { envelope in
            var prefs = envelope["preferences"] as! [String: Any]
            prefs.removeValue(forKey: "advanced")
            envelope["preferences"] = prefs
        }
        let restored = try PreferencesBackup.decode(oldBackup)
        #expect(restored == original)
        #expect(restored.advanced == nil)
        #expect(restored.options == TaskbarAdvancedOptions())

        let partial = try modified(oldBackup) { envelope in
            var prefs = envelope["preferences"] as! [String: Any]
            prefs["advanced"] = ["previewWidth": 480, "middleClickClosesWindow": true]
            envelope["preferences"] = prefs
        }
        let migrated = try PreferencesBackup.decode(partial)
        #expect(migrated.options.previewWidth == 480)
        #expect(migrated.options.middleClickClosesWindow)
        #expect(migrated.options.horizontalPadding == 10)
        #expect(migrated.layout == original.layout)
        #expect(migrated.pinnedApplicationPaths == original.pinnedApplicationPaths)
    }

    @Test func advancedOptionsRoundTripEveryCustomValue() throws {
        var preferences = BuiltInPreset.compact.preferences
        var options = TaskbarAdvancedOptions()
        options.horizontalPadding = 17; options.verticalPadding = 9
        options.sectionSpacing = 21; options.labelSpacing = 11; options.itemHorizontalPadding = 15
        options.iconOnlyUsesItemHeight = false; options.iconOnlyWidth = 68
        options.barBorderWidth = 2.5; options.barBorderOpacity = 0.31; options.barShadow = false
        options.minimizedOpacity = 0.45; options.hiddenOpacity = 0.3; options.dimHiddenWindows = false
        options.showMinimizedIndicator = false; options.showAppBadges = true
        options.allowWindowDragging = false; options.allowPinDragging = false
        options.focusedClickHidesApplication = true; options.middleClickClosesWindow = true
        options.hoverPreviewsEnabled = true; options.previewDelay = 0.85
        options.previewWidth = 500; options.previewHeight = 320; options.previewTitleFontSize = 15
        options.startMenuWidth = 800; options.startMenuHeight = 700
        options.startMenuFontSize = 17; options.startMenuIconSize = 30
        options.autoHideDelay = 1.2; options.revealDelay = 0.4
        options.revealStrip = 7; options.animationDuration = 0.3
        options.resizeOverlappingWindows = true; options.hideInFullscreen = true; options.useScreenFrame = true
        options.nativeSpaceTracking = false; options.showAllSpacesIndicator = false
        options.hiddenDisplayIDs = [53, 98]
        preferences.options = options
        let restored = try PreferencesBackup.decode(PreferencesBackup.encode(preferences))
        #expect(restored == preferences)
        #expect(restored.options == options)
        #expect(restored.options.hiddenDisplayIDs == [53, 98])
    }

    @Test func advancedRangesRejectNonfiniteAndOutOfBounds() throws {
        let ranges: [(WritableKeyPath<TaskbarAdvancedOptions, Double>, ClosedRange<Double>)] = [
            (\.horizontalPadding, CustomizationLimits.padding), (\.verticalPadding, CustomizationLimits.padding),
            (\.sectionSpacing, CustomizationLimits.spacing), (\.labelSpacing, CustomizationLimits.spacing),
            (\.itemHorizontalPadding, CustomizationLimits.padding), (\.iconOnlyWidth, CustomizationLimits.itemWidth),
            (\.barBorderWidth, CustomizationLimits.borderWidth), (\.barBorderOpacity, CustomizationLimits.opacity),
            (\.minimizedOpacity, CustomizationLimits.opacity), (\.hiddenOpacity, CustomizationLimits.opacity),
            (\.previewDelay, CustomizationLimits.delay), (\.previewWidth, CustomizationLimits.previewWidth),
            (\.previewHeight, CustomizationLimits.previewHeight), (\.previewTitleFontSize, CustomizationLimits.fontSize),
            (\.startMenuWidth, CustomizationLimits.startMenuWidth), (\.startMenuHeight, CustomizationLimits.startMenuHeight),
            (\.startMenuFontSize, CustomizationLimits.fontSize), (\.startMenuIconSize, CustomizationLimits.iconSize),
            (\.autoHideDelay, CustomizationLimits.delay), (\.revealDelay, CustomizationLimits.delay),
            (\.revealStrip, CustomizationLimits.revealStrip), (\.animationDuration, CustomizationLimits.animationDuration)
        ]
        for (key, range) in ranges {
            for value in [range.lowerBound, range.upperBound] {
                var preferences = TaskPanePreferences()
                preferences.options[keyPath: key] = value
                #expect(try PreferencesBackup.decode(PreferencesBackup.encode(preferences)) == preferences)
            }
            for value in [range.lowerBound - 0.01, range.upperBound + 0.01, .nan, .infinity, -.infinity] {
                var preferences = TaskPanePreferences()
                preferences.options[keyPath: key] = value
                #expect(throws: (any Error).self) { try preferences.validate() }
                #expect(throws: (any Error).self) { try PreferencesBackup.encode(preferences) }
            }
        }
        var duplicateIDs = TaskPanePreferences()
        duplicateIDs.options.hiddenDisplayIDs = [7, 7]
        #expect(throws: (any Error).self) { try duplicateIDs.validate() }
        duplicateIDs.options.hiddenDisplayIDs = Array(0..<33)
        #expect(throws: (any Error).self) { try duplicateIDs.validate() }
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

    @Test func combinedMoveUsesDisplayedSessionOrderInsteadOfOlderSavedOrder() throws {
        var layout = LayoutCustomization()
        layout.autoArrange = false
        layout.applicationOrder = ["A", "B", "C", "not-running"]
        // Individual window dragging put C first before the user combined apps.
        let result = try #require(layout.movingApplication("B", before: "C", currentOrder: ["C", "A", "B"],
                                                         usingDisplayedOrder: true))
        #expect(result.applicationOrder == ["B", "C", "A", "not-running"])
        #expect(!result.autoArrange)
        #expect(layout.applicationOrder == ["A", "B", "C", "not-running"])
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
        original.options.startMenuWidth = 800
        original.options.middleClickClosesWindow = true

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
