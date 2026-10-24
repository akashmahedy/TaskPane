import Foundation

public enum AppMode: String, Codable, CaseIterable, Identifiable {
    case taskbar, menubar, combined
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .taskbar: return "Taskbar"
        case .menubar: return "Menu bar"
        case .combined: return "Taskbar & menu bar"
        }
    }
}

public enum BarEdge: String, Codable, CaseIterable, Identifiable {
    case bottom, top, left, right
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum GroupingMode: String, Codable, CaseIterable, Identifiable {
    case never, adjacent, always, automatic
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .never: return "Separate windows"
        case .adjacent: return "Keep app windows together"
        case .always: return "Combine into app buttons"
        case .automatic: return "Combine when space is needed"
        }
    }
}

public enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum BarAlignment: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum ItemSizing: String, Codable, CaseIterable, Identifiable {
    case adaptive, fixed
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum WindowSortOrder: String, Codable, CaseIterable, Identifiable {
    case application, title, recent
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .application: return "Application"
        case .title: return "Window title"
        case .recent: return "Most recent"
        }
    }
}

public enum BarSection: String, Codable, CaseIterable, Identifiable {
    case launcher, pins, windows, widgets, settings
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .launcher: return "Launcher"
        case .pins: return "Pinned apps"
        case .windows: return "Windows"
        case .widgets: return "Widgets"
        case .settings: return "Settings"
        }
    }
}

public struct LayoutCustomization: Codable, Equatable {
    public var alignment: BarAlignment = .center
    public var lengthPercent: Double = 98
    public var edgeOffset: Double = 10
    public var alongEdgeOffset: Double = 0
    public var itemSizing: ItemSizing = .adaptive
    public var itemWidth: Double = 160
    public var minItemWidth: Double = 90
    public var maxItemWidth: Double = 220
    public var itemHeight: Double = 34
    public var itemSpacing: Double = 6
    public var itemOpacity: Double = 0.08
    public var itemCornerRadius: Double = 7
    public var barCornerRadius: Double = 13
    public var autoArrange: Bool = true
    public var sortOrder: WindowSortOrder = .application
    public var applicationOrder: [String] = []
    public var sectionOrder: [BarSection] = BarSection.allCases
    public var showDividers: Bool = true
    public var showActiveIndicator: Bool = true
    public var showMinimizedWindows: Bool = true
    public var showOffscreenWindows: Bool = false
    public var showDialogs: Bool = false

    public init() {}

    /// Begins manual ordering from what the user currently sees. An older manual
    /// order must not reorder unrelated apps after automatic sorting was enabled.
    public func movingApplication(_ key: String, before target: String, currentOrder: [String], usingDisplayedOrder: Bool = false) -> LayoutCustomization? {
        let source = autoArrange || usingDisplayedOrder ? currentOrder + applicationOrder : applicationOrder + currentOrder
        var seen = Set<String>()
        var order = source.filter { seen.insert($0).inserted }
        guard key != target, order.contains(key), order.contains(target) else { return nil }
        order.removeAll { $0 == key }
        guard let targetIndex = order.firstIndex(of: target) else { return nil }
        order.insert(key, at: targetIndex)
        var updated = self
        updated.applicationOrder = order
        updated.autoArrange = false
        return updated
    }

    public func movingApplication(_ key: String, direction: Int, currentOrder: [String]) -> LayoutCustomization? {
        guard direction == -1 || direction == 1,
              let index = currentOrder.firstIndex(of: key),
              currentOrder.indices.contains(index + direction) else { return nil }
        let neighbor = currentOrder[index + direction]
        if direction < 0 { return movingApplication(key, before: neighbor, currentOrder: currentOrder) }
        return movingApplication(neighbor, before: key, currentOrder: currentOrder)
    }

    public func validate() throws {
        try Self.check(lengthPercent, in: CustomizationLimits.lengthPercent, field: "bar length")
        try Self.check(edgeOffset, in: CustomizationLimits.edgeOffset, field: "edge offset")
        try Self.check(alongEdgeOffset, in: CustomizationLimits.alongEdgeOffset, field: "position offset")
        try Self.check(itemWidth, in: CustomizationLimits.itemWidth, field: "item width")
        try Self.check(minItemWidth, in: CustomizationLimits.itemWidth, field: "minimum item width")
        try Self.check(maxItemWidth, in: CustomizationLimits.itemWidth, field: "maximum item width")
        try Self.check(itemHeight, in: CustomizationLimits.itemHeight, field: "item height")
        try Self.check(itemSpacing, in: CustomizationLimits.spacing, field: "item spacing")
        try Self.check(itemOpacity, in: CustomizationLimits.opacity, field: "item opacity")
        try Self.check(itemCornerRadius, in: CustomizationLimits.cornerRadius, field: "item corner radius")
        try Self.check(barCornerRadius, in: CustomizationLimits.cornerRadius, field: "bar corner radius")
        guard minItemWidth <= maxItemWidth else {
            throw PreferencesError.invalidValue(field: "item width limits", reason: "minimum must not exceed maximum")
        }
        guard applicationOrder.count <= 200,
              Set(applicationOrder).count == applicationOrder.count,
              applicationOrder.allSatisfy({
                  !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 255 &&
                  !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
              }) else {
            throw PreferencesError.invalidValue(field: "application order", reason: "use at most 200 unique nonempty identifiers of up to 255 characters")
        }
        guard sectionOrder.count == BarSection.allCases.count,
              Set(sectionOrder).count == BarSection.allCases.count else {
            throw PreferencesError.invalidValue(field: "section order", reason: "include each section exactly once")
        }
    }

    private static func check(_ value: Double, in range: ClosedRange<Double>, field: String) throws {
        guard value.isFinite, range.contains(value) else {
            throw PreferencesError.invalidValue(field: field, reason: "use a value from \(range.lowerBound) to \(range.upperBound)")
        }
    }
}

public enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case cpu, memory, network, battery, clock
    public var id: String { rawValue }
    public var supportsGraph: Bool { self == .cpu || self == .memory }
    public var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .battery: return "Battery"
        case .clock: return "Clock"
        }
    }
}

public enum WidgetPlacement: String, Codable, CaseIterable, Identifiable {
    case off, taskbar, menubar, both
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .taskbar: return "Taskbar"
        case .menubar: return "Menu bar"
        case .both: return "Both"
        }
    }
    public var showsInTaskbar: Bool { self == .taskbar || self == .both }
    public var showsInMenubar: Bool { self == .menubar || self == .both }
}

public enum WidgetStyle: String, Codable, CaseIterable, Identifiable {
    case number, compact, graph
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public struct WidgetConfiguration: Codable, Equatable, Identifiable {
    public var kind: WidgetKind
    public var id: String { kind.rawValue }
    public var placement: WidgetPlacement
    public var showLabel: Bool
    public var style: WidgetStyle

    public init(
        kind: WidgetKind,
        placement: WidgetPlacement = .taskbar,
        showLabel: Bool = true,
        style: WidgetStyle = .compact
    ) {
        self.kind = kind
        self.placement = placement
        self.showLabel = showLabel
        self.style = style
    }
}

public enum PreferencesError: Error, LocalizedError, Equatable {
    case invalidValue(field: String, reason: String)
    case unsupportedSchemaVersion(Int)
    case unsupportedFormat
    case backupTooLarge
    case malformedBackup

    public var errorDescription: String? {
        switch self {
        case let .invalidValue(field, reason):
            return "Invalid \(field): \(reason)."
        case let .unsupportedSchemaVersion(version):
            return "This preferences version (\(version)) is not supported by this version of TaskPane."
        case .unsupportedFormat:
            return "This file is not a TaskPane preferences backup."
        case .backupTooLarge:
            return "The preferences backup exceeds the 1 MiB size limit."
        case .malformedBackup:
            return "The preferences backup is incomplete or contains invalid data."
        }
    }
}

public struct TaskPanePreferences: Codable, Equatable {
    public var schemaVersion: Int = 1
    public var appMode: AppMode = .combined
    public var barEdge: BarEdge = .bottom
    public var grouping: GroupingMode = .never
    public var theme: ThemeMode = .system
    public var barHeight: Double = 54
    public var barOpacity: Double = 0.96
    public var iconSize: Double = 22
    public var fontSize: Double = 12
    public var showWindowTitles: Bool = true
    public var secondClickMinimizes: Bool = true
    public var autoHide: Bool = false
    public var showOnAllDisplays: Bool = false
    public var currentDisplayOnly: Bool = true
    public var showLauncher: Bool = true
    public var showClock: Bool = true
    public var showAppNames: Bool = true
    public var reduceMotion: Bool = false
    public var accentHex: String = "5B8CFF"
    public var refreshInterval: Double = 2
    public var pinnedApplicationPaths: [String] = []
    public var excludedBundleIdentifiers: [String] = []
    /// Optional storage keeps schema-1 backups from the original alpha decodable.
    public var customization: LayoutCustomization? = nil
    public var advanced: TaskbarAdvancedOptions? = nil
    public var options: TaskbarAdvancedOptions {
        get { advanced ?? TaskbarAdvancedOptions() }
        set { advanced = newValue }
    }
    public var layout: LayoutCustomization {
        get { customization ?? LayoutCustomization() }
        set { customization = newValue }
    }
    public var widgets: [WidgetConfiguration] = [
        WidgetConfiguration(kind: .cpu),
        WidgetConfiguration(kind: .memory),
        WidgetConfiguration(kind: .network),
        WidgetConfiguration(kind: .battery, placement: .menubar),
        WidgetConfiguration(kind: .clock)
    ]

    public init() {}

    /// Changes window behavior without replacing the user's visual setup,
    /// widgets, saved application order, pins or exclusions.
    public func usingTaskbarBehavior() -> TaskPanePreferences {
        var updated = self
        updated.grouping = .adjacent
        updated.showWindowTitles = true
        updated.secondClickMinimizes = true
        updated.currentDisplayOnly = false
        updated.layout.showMinimizedWindows = true
        updated.layout.showOffscreenWindows = true
        updated.layout.autoArrange = false
        return updated
    }

    /// Scales the taskbar's principal dimensions in one preference transaction.
    /// Every size remains within its independently supported range.
    public func usingOverallScale(_ percent: Double) -> TaskPanePreferences {
        guard percent.isFinite else { return self }
        func fit(_ value: Double, _ range: ClosedRange<Double>) -> Double { min(range.upperBound, max(range.lowerBound, value)) }
        let scale = fit(percent, CustomizationLimits.overallScale) / 100
        var updated = self
        updated.barHeight = fit(50 * scale, CustomizationLimits.barHeight)
        updated.iconSize = fit(22 * scale, CustomizationLimits.iconSize)
        updated.fontSize = fit(12 * scale, CustomizationLimits.fontSize)
        updated.layout.itemHeight = fit(40 * scale, CustomizationLimits.itemHeight)
        updated.layout.itemWidth = fit(184 * scale, CustomizationLimits.itemWidth)
        updated.layout.minItemWidth = fit(120 * scale, CustomizationLimits.itemWidth)
        updated.layout.maxItemWidth = fit(240 * scale, CustomizationLimits.itemWidth)
        updated.layout.itemSpacing = fit(3 * scale, CustomizationLimits.spacing)
        updated.options.horizontalPadding = fit(10 * scale, CustomizationLimits.padding)
        updated.options.verticalPadding = fit(5 * scale, CustomizationLimits.padding)
        return updated
    }

    /// Checks a complete snapshot without changing it or touching any referenced files.
    public func validate() throws {
        guard schemaVersion == 1 else { throw PreferencesError.unsupportedSchemaVersion(schemaVersion) }
        try Self.check(barHeight, in: CustomizationLimits.barHeight, field: "bar height")
        try Self.check(barOpacity, in: CustomizationLimits.opacity, field: "bar opacity")
        try Self.check(iconSize, in: CustomizationLimits.iconSize, field: "icon size")
        try Self.check(fontSize, in: CustomizationLimits.fontSize, field: "font size")
        try Self.check(refreshInterval, in: 1...60, field: "refresh interval")
        try layout.validate()
        try options.validate()

        guard accentHex.count == 6,
              accentHex.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) else {
            throw PreferencesError.invalidValue(field: "accent color", reason: "use six hexadecimal digits")
        }

        guard widgets.count == WidgetKind.allCases.count,
              Set(widgets.map(\.kind)).count == WidgetKind.allCases.count else {
            throw PreferencesError.invalidValue(field: "widgets", reason: "include each widget exactly once")
        }

        guard pinnedApplicationPaths.count <= 100 else {
            throw PreferencesError.invalidValue(field: "pinned apps", reason: "at most 100 apps are supported")
        }
        var uniquePaths = Set<String>()
        for path in pinnedApplicationPaths {
            let components = path.split(separator: "/", omittingEmptySubsequences: true)
            // Backups contain application paths only, never commands, URLs or scripts.
            guard path.utf8.count <= 4096,
                  (path as NSString).isAbsolutePath,
                  !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !components.contains("."), !components.contains(".."),
                  (path as NSString).pathExtension.lowercased() == "app" else {
                throw PreferencesError.invalidValue(field: "pinned app", reason: "use an absolute .app path")
            }
            let normalized = "/" + components.joined(separator: "/")
            guard uniquePaths.insert(normalized).inserted else {
                throw PreferencesError.invalidValue(field: "pinned apps", reason: "duplicate app paths are not allowed")
            }
        }

        let identifierCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        guard excludedBundleIdentifiers.count <= 1000,
              Set(excludedBundleIdentifiers).count == excludedBundleIdentifiers.count,
              excludedBundleIdentifiers.allSatisfy({ identifier in
                  !identifier.isEmpty && identifier.utf8.count <= 255 &&
                  identifier.unicodeScalars.allSatisfy { identifierCharacters.contains($0) }
              }) else {
            throw PreferencesError.invalidValue(field: "excluded apps", reason: "use unique valid bundle identifiers")
        }
    }

    private static func check(_ value: Double, in range: ClosedRange<Double>, field: String) throws {
        guard value.isFinite, range.contains(value) else {
            throw PreferencesError.invalidValue(field: field, reason: "use a value from \(range.lowerBound) to \(range.upperBound)")
        }
    }
}

public enum BuiltInPreset: String, CaseIterable, Identifiable {
    case balanced, windows, compact, monitoring, focus
    case dockLike, bubbles, rosePine, translucent, transparent, squircle
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .dockLike: return "DockLike"
        case .bubbles: return "Bubbles"
        case .rosePine: return "Rosé Pine"
        case .translucent: return "Translucent"
        case .transparent: return "Simply Transparent"
        case .squircle: return "Squircle"
        case .balanced: return "Balanced"
        case .windows: return "Windows style"
        case .compact: return "Compact"
        case .monitoring: return "Monitoring"
        case .focus: return "Focus"
        }
    }
    public var subtitle: String {
        switch self {
        case .dockLike: return "Windhawk inspired · Amber. A centered floating dock with roomy icons."
        case .bubbles: return "Windhawk inspired · m417z. Separated pill buttons on a clear bar."
        case .rosePine: return "Windhawk inspired · asev. A muted violet surface with rose highlights."
        case .translucent: return "Windhawk inspired. A wide, softly translucent taskbar."
        case .transparent: return "Windhawk inspired. Minimal icons floating over your desktop."
        case .squircle: return "Windhawk inspired. Rounded square buttons and a compact silhouette."
        case .balanced: return "A floating taskbar with readable titles and CPU/RAM graphs."
        case .windows: return "Full-width, square-edged taskbar with wide window buttons."
        case .compact: return "A small floating window bar, with monitoring in the menu bar."
        case .monitoring: return "System readings in the menu bar, with the taskbar hidden."
        case .focus: return "A thin icon bar that hides automatically and keeps widgets off."
        }
    }
    public var preferences: TaskPanePreferences {
        var result = TaskPanePreferences()
        var layout = LayoutCustomization()
        switch self {
        case .dockLike, .bubbles, .rosePine, .translucent, .transparent, .squircle:
            result.appMode = .taskbar
            result.grouping = .never
            result.showWindowTitles = false
            result.showAppNames = false
            result.showClock = false
            result.barHeight = 56
            result.iconSize = 28
            layout.lengthPercent = 65
            layout.edgeOffset = 12
            layout.itemSizing = .fixed
            layout.itemWidth = 44
            layout.minItemWidth = 44
            layout.maxItemWidth = 100
            layout.itemHeight = 40
            layout.itemSpacing = 8
            layout.itemCornerRadius = 12
            layout.barCornerRadius = 18
            layout.showDividers = false
            var options = TaskbarAdvancedOptions()
            result.widgets = WidgetKind.allCases.map { WidgetConfiguration(kind: $0, placement: .off) }
            switch self {
            case .dockLike:
                layout.lengthPercent = 58; layout.itemHeight = 44; layout.itemCornerRadius = 10
                result.barOpacity = 0.88; options.horizontalPadding = 14
            case .bubbles:
                layout.lengthPercent = 78; layout.itemCornerRadius = 24; layout.itemSpacing = 14
                layout.itemOpacity = 0.22; result.barOpacity = 0; options.barBorderWidth = 0; options.barShadow = false
            case .rosePine:
                result.theme = .dark; result.accentHex = "EBBCBA"; result.barOpacity = 1
                options.barBackgroundHex = "191724"; options.itemBackgroundHex = "403D52"
                layout.itemOpacity = 0.8; layout.lengthPercent = 94; layout.itemCornerRadius = 6
                result.showWindowTitles = true; result.fontSize = 12; layout.maxItemWidth = 220; layout.itemSizing = .adaptive
            case .translucent:
                layout.lengthPercent = 100; layout.edgeOffset = 0; layout.barCornerRadius = 0
                result.barOpacity = 0.36; layout.itemSpacing = 6; layout.itemOpacity = 0.08
            case .transparent:
                layout.lengthPercent = 88; layout.itemOpacity = 0; result.barOpacity = 0
                options.barBorderWidth = 0; options.barShadow = false; layout.itemSpacing = 18
            case .squircle:
                layout.lengthPercent = 70; layout.itemCornerRadius = 16; layout.barCornerRadius = 24
                layout.itemOpacity = 0.18; layout.itemHeight = 46; layout.itemSpacing = 5
                result.barOpacity = 0.94; result.accentHex = "A078E8"
            default: break
            }
            result.options = options
        case .balanced:
            layout.lengthPercent = 92
            layout.edgeOffset = 12
            layout.itemWidth = 156
            layout.minItemWidth = 108
            layout.maxItemWidth = 200
            layout.itemHeight = 36
            layout.itemSpacing = 7
            layout.itemCornerRadius = 9
            layout.barCornerRadius = 16
            result.widgets = WidgetKind.allCases.map {
                WidgetConfiguration(kind: $0, placement: $0 == .battery ? .menubar : .taskbar,
                                    style: $0.supportsGraph ? .graph : $0 == .clock ? .number : .compact)
            }
        case .windows:
            result.appMode = .taskbar
            result.barHeight = 50
            result.barOpacity = 1
            result.grouping = .never
            layout.alignment = .leading
            layout.lengthPercent = 100
            layout.edgeOffset = 0
            layout.itemSizing = .fixed
            layout.itemWidth = 184
            layout.minItemWidth = 120
            layout.maxItemWidth = 240
            layout.itemHeight = 40
            layout.itemSpacing = 3
            layout.itemOpacity = 0.06
            layout.itemCornerRadius = 4
            layout.barCornerRadius = 0
            result.widgets = WidgetKind.allCases.map {
                WidgetConfiguration(kind: $0, placement: $0 == .clock ? .taskbar : .off, style: .number)
            }
        case .compact:
            result.barHeight = 44
            result.iconSize = 24
            result.fontSize = 11
            result.grouping = .adjacent
            result.showWindowTitles = false
            result.showAppNames = false
            result.showClock = false
            layout.lengthPercent = 62
            layout.edgeOffset = 14
            layout.itemSizing = .fixed
            layout.itemWidth = 48
            layout.minItemWidth = 48
            layout.maxItemWidth = 64
            layout.itemHeight = 32
            layout.itemSpacing = 4
            layout.itemOpacity = 0.06
            layout.itemCornerRadius = 10
            layout.barCornerRadius = 18
            layout.showDividers = false
            layout.sectionOrder = [.launcher, .pins, .windows, .settings, .widgets]
            result.widgets = WidgetKind.allCases.map {
                WidgetConfiguration(kind: $0, placement: .menubar, showLabel: false)
            }
        case .monitoring:
            result.appMode = .menubar
            layout.alignment = .trailing
            layout.lengthPercent = 72
            layout.edgeOffset = 12
            layout.sectionOrder = [.widgets, .launcher, .pins, .windows, .settings]
            result.widgets = WidgetKind.allCases.map {
                WidgetConfiguration(kind: $0, placement: .menubar, style: $0.supportsGraph ? .graph : .number)
            }
        case .focus:
            result.appMode = .taskbar
            result.autoHide = true
            result.barHeight = 36
            result.iconSize = 18
            result.fontSize = 10
            result.grouping = .adjacent
            result.showLauncher = false
            result.showWindowTitles = false
            result.showAppNames = false
            result.showClock = false
            layout.lengthPercent = 48
            layout.edgeOffset = 8
            layout.itemSizing = .fixed
            layout.itemWidth = 48
            layout.minItemWidth = 48
            layout.maxItemWidth = 72
            layout.itemHeight = 24
            layout.itemSpacing = 3
            layout.itemOpacity = 0
            layout.itemCornerRadius = 6
            layout.barCornerRadius = 10
            layout.autoArrange = false
            layout.sortOrder = .recent
            layout.showDividers = false
            layout.sectionOrder = [.windows, .pins, .launcher, .widgets, .settings]
            result.widgets = WidgetKind.allCases.map {
                WidgetConfiguration(kind: $0, placement: .off, showLabel: false)
            }
        }
        result.layout = layout
        return result
    }
}

public enum PreferencesBackup {
    public static let maximumDataSize = 1_048_576
    public static let format = "TaskPane.preferences"

    private struct Header: Decodable {
        let format: String
        let schemaVersion: Int
    }
    private struct Envelope: Codable {
        let format: String
        let schemaVersion: Int
        let exportedAtISODate: String
        let preferences: TaskPanePreferences
    }

    public static func encode(_ preferences: TaskPanePreferences) throws -> Data {
        try preferences.validate()
        let envelope = Envelope(
            format: format,
            schemaVersion: 1,
            exportedAtISODate: ISO8601DateFormatter().string(from: Date()),
            preferences: preferences
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(envelope)
        guard data.count <= maximumDataSize else { throw PreferencesError.backupTooLarge }
        return data
    }

    /// Decodes and validates completely before returning a replacement snapshot.
    public static func decode(_ data: Data) throws -> TaskPanePreferences {
        guard data.count <= maximumDataSize else { throw PreferencesError.backupTooLarge }
        let decoder = JSONDecoder()
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.format == format else { throw PreferencesError.unsupportedFormat }
            guard header.schemaVersion == 1 else {
                throw PreferencesError.unsupportedSchemaVersion(header.schemaVersion)
            }
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard ISO8601DateFormatter().date(from: envelope.exportedAtISODate) != nil else {
                throw PreferencesError.malformedBackup
            }
            var preferences = envelope.preferences
            // Early schema-1 builds offered graphs for modules without a history
            // series. Keep those backups usable, falling back to an honest number.
            for index in preferences.widgets.indices where
                preferences.widgets[index].style == .graph && !preferences.widgets[index].kind.supportsGraph {
                preferences.widgets[index].style = .number
            }
            try preferences.validate()
            return preferences
        } catch let error as PreferencesError {
            throw error
        } catch {
            throw PreferencesError.malformedBackup
        }
    }
}
