import Foundation

/// Shared model and UI limits. Requested sizes are fitted to the connected display.
public enum CustomizationLimits {
    public static let overallScale: ClosedRange<Double> = 50...250
    public static let barHeight: ClosedRange<Double> = 24...256
    public static let opacity: ClosedRange<Double> = 0...1
    public static let iconSize: ClosedRange<Double> = 8...128
    public static let fontSize: ClosedRange<Double> = 8...48
    public static let lengthPercent: ClosedRange<Double> = 10...100
    public static let edgeOffset: ClosedRange<Double> = 0...1000
    public static let alongEdgeOffset: ClosedRange<Double> = -4000...4000
    public static let itemWidth: ClosedRange<Double> = 24...1200
    public static let itemHeight: ClosedRange<Double> = 20...240
    public static let spacing: ClosedRange<Double> = 0...100
    public static let cornerRadius: ClosedRange<Double> = 0...128
    public static let padding: ClosedRange<Double> = 0...100
    public static let borderWidth: ClosedRange<Double> = 0...12
    public static let delay: ClosedRange<Double> = 0...10
    public static let previewWidth: ClosedRange<Double> = 120...1000
    public static let previewHeight: ClosedRange<Double> = 80...800
    public static let startMenuWidth: ClosedRange<Double> = 320...1200
    public static let startMenuHeight: ClosedRange<Double> = 240...1200
    public static let revealStrip: ClosedRange<Double> = 1...40
    public static let animationDuration: ClosedRange<Double> = 0...2
}

/// Optional storage keeps existing schema-one preferences readable. Missing options
/// inside this container receive the same defaults as a newly created setup.
public struct TaskbarAdvancedOptions: Codable, Equatable {
    public var horizontalPadding: Double = 10
    public var verticalPadding: Double = 6
    public var sectionSpacing: Double = 10
    public var labelSpacing: Double = 7
    public var itemHorizontalPadding: Double = 7
    public var iconOnlyUsesItemHeight: Bool = true
    public var iconOnlyWidth: Double = 48
    public var barBorderWidth: Double = 1
    public var barBorderOpacity: Double = 0.12
    public var barShadow: Bool = true
    public var minimizedOpacity: Double = 0.6
    public var hiddenOpacity: Double = 0.6
    public var dimHiddenWindows: Bool = true
    public var showMinimizedIndicator: Bool = true
    public var showAppBadges: Bool = false
    public var allowWindowDragging: Bool = true
    public var allowPinDragging: Bool = true
    public var focusedClickHidesApplication: Bool = false
    public var middleClickClosesWindow: Bool = false
    public var hoverPreviewsEnabled: Bool = false
    public var previewDelay: Double = 0.5
    public var previewWidth: Double = 280
    public var previewHeight: Double = 180
    public var previewTitleFontSize: Double = 12
    public var startMenuWidth: Double = 480
    public var startMenuHeight: Double = 560
    public var startMenuFontSize: Double = 12
    public var startMenuIconSize: Double = 20
    public var autoHideDelay: Double = 0.7
    public var revealDelay: Double = 0
    public var revealStrip: Double = 5
    public var animationDuration: Double = 0.15
    public var resizeOverlappingWindows: Bool = false
    public var hideInFullscreen: Bool = false
    public var useScreenFrame: Bool = false
    public var nativeSpaceTracking: Bool = true
    public var showAllSpacesIndicator: Bool = true
    public var hiddenDisplayIDs: [UInt32] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case horizontalPadding
        case verticalPadding
        case sectionSpacing
        case labelSpacing
        case itemHorizontalPadding
        case iconOnlyUsesItemHeight
        case iconOnlyWidth
        case barBorderWidth
        case barBorderOpacity
        case barShadow
        case minimizedOpacity
        case hiddenOpacity
        case dimHiddenWindows
        case showMinimizedIndicator
        case showAppBadges
        case allowWindowDragging
        case allowPinDragging
        case focusedClickHidesApplication
        case middleClickClosesWindow
        case hoverPreviewsEnabled
        case previewDelay
        case previewWidth
        case previewHeight
        case previewTitleFontSize
        case startMenuWidth
        case startMenuHeight
        case startMenuFontSize
        case startMenuIconSize
        case autoHideDelay
        case revealDelay
        case revealStrip
        case animationDuration
        case resizeOverlappingWindows
        case hideInFullscreen
        case useScreenFrame
        case nativeSpaceTracking
        case showAllSpacesIndicator
        case hiddenDisplayIDs
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        horizontalPadding = try values.decodeIfPresent(Double.self, forKey: .horizontalPadding) ?? horizontalPadding
        verticalPadding = try values.decodeIfPresent(Double.self, forKey: .verticalPadding) ?? verticalPadding
        sectionSpacing = try values.decodeIfPresent(Double.self, forKey: .sectionSpacing) ?? sectionSpacing
        labelSpacing = try values.decodeIfPresent(Double.self, forKey: .labelSpacing) ?? labelSpacing
        itemHorizontalPadding = try values.decodeIfPresent(Double.self, forKey: .itemHorizontalPadding) ?? itemHorizontalPadding
        iconOnlyUsesItemHeight = try values.decodeIfPresent(Bool.self, forKey: .iconOnlyUsesItemHeight) ?? iconOnlyUsesItemHeight
        iconOnlyWidth = try values.decodeIfPresent(Double.self, forKey: .iconOnlyWidth) ?? iconOnlyWidth
        barBorderWidth = try values.decodeIfPresent(Double.self, forKey: .barBorderWidth) ?? barBorderWidth
        barBorderOpacity = try values.decodeIfPresent(Double.self, forKey: .barBorderOpacity) ?? barBorderOpacity
        barShadow = try values.decodeIfPresent(Bool.self, forKey: .barShadow) ?? barShadow
        minimizedOpacity = try values.decodeIfPresent(Double.self, forKey: .minimizedOpacity) ?? minimizedOpacity
        hiddenOpacity = try values.decodeIfPresent(Double.self, forKey: .hiddenOpacity) ?? hiddenOpacity
        dimHiddenWindows = try values.decodeIfPresent(Bool.self, forKey: .dimHiddenWindows) ?? dimHiddenWindows
        showMinimizedIndicator = try values.decodeIfPresent(Bool.self, forKey: .showMinimizedIndicator) ?? showMinimizedIndicator
        showAppBadges = try values.decodeIfPresent(Bool.self, forKey: .showAppBadges) ?? showAppBadges
        allowWindowDragging = try values.decodeIfPresent(Bool.self, forKey: .allowWindowDragging) ?? allowWindowDragging
        allowPinDragging = try values.decodeIfPresent(Bool.self, forKey: .allowPinDragging) ?? allowPinDragging
        focusedClickHidesApplication = try values.decodeIfPresent(Bool.self, forKey: .focusedClickHidesApplication) ?? focusedClickHidesApplication
        middleClickClosesWindow = try values.decodeIfPresent(Bool.self, forKey: .middleClickClosesWindow) ?? middleClickClosesWindow
        hoverPreviewsEnabled = try values.decodeIfPresent(Bool.self, forKey: .hoverPreviewsEnabled) ?? hoverPreviewsEnabled
        previewDelay = try values.decodeIfPresent(Double.self, forKey: .previewDelay) ?? previewDelay
        previewWidth = try values.decodeIfPresent(Double.self, forKey: .previewWidth) ?? previewWidth
        previewHeight = try values.decodeIfPresent(Double.self, forKey: .previewHeight) ?? previewHeight
        previewTitleFontSize = try values.decodeIfPresent(Double.self, forKey: .previewTitleFontSize) ?? previewTitleFontSize
        startMenuWidth = try values.decodeIfPresent(Double.self, forKey: .startMenuWidth) ?? startMenuWidth
        startMenuHeight = try values.decodeIfPresent(Double.self, forKey: .startMenuHeight) ?? startMenuHeight
        startMenuFontSize = try values.decodeIfPresent(Double.self, forKey: .startMenuFontSize) ?? startMenuFontSize
        startMenuIconSize = try values.decodeIfPresent(Double.self, forKey: .startMenuIconSize) ?? startMenuIconSize
        autoHideDelay = try values.decodeIfPresent(Double.self, forKey: .autoHideDelay) ?? autoHideDelay
        revealDelay = try values.decodeIfPresent(Double.self, forKey: .revealDelay) ?? revealDelay
        revealStrip = try values.decodeIfPresent(Double.self, forKey: .revealStrip) ?? revealStrip
        animationDuration = try values.decodeIfPresent(Double.self, forKey: .animationDuration) ?? animationDuration
        resizeOverlappingWindows = try values.decodeIfPresent(Bool.self, forKey: .resizeOverlappingWindows) ?? resizeOverlappingWindows
        hideInFullscreen = try values.decodeIfPresent(Bool.self, forKey: .hideInFullscreen) ?? hideInFullscreen
        useScreenFrame = try values.decodeIfPresent(Bool.self, forKey: .useScreenFrame) ?? useScreenFrame
        nativeSpaceTracking = try values.decodeIfPresent(Bool.self, forKey: .nativeSpaceTracking) ?? nativeSpaceTracking
        showAllSpacesIndicator = try values.decodeIfPresent(Bool.self, forKey: .showAllSpacesIndicator) ?? showAllSpacesIndicator
        hiddenDisplayIDs = try values.decodeIfPresent([UInt32].self, forKey: .hiddenDisplayIDs) ?? hiddenDisplayIDs
    }

    public func validate() throws {
        try Self.check(horizontalPadding, in: CustomizationLimits.padding, field: "horizontalPadding")
        try Self.check(verticalPadding, in: CustomizationLimits.padding, field: "verticalPadding")
        try Self.check(sectionSpacing, in: CustomizationLimits.spacing, field: "sectionSpacing")
        try Self.check(labelSpacing, in: CustomizationLimits.spacing, field: "labelSpacing")
        try Self.check(itemHorizontalPadding, in: CustomizationLimits.padding, field: "itemHorizontalPadding")
        try Self.check(iconOnlyWidth, in: CustomizationLimits.itemWidth, field: "iconOnlyWidth")
        try Self.check(barBorderWidth, in: CustomizationLimits.borderWidth, field: "barBorderWidth")
        try Self.check(barBorderOpacity, in: CustomizationLimits.opacity, field: "barBorderOpacity")
        try Self.check(minimizedOpacity, in: CustomizationLimits.opacity, field: "minimizedOpacity")
        try Self.check(hiddenOpacity, in: CustomizationLimits.opacity, field: "hiddenOpacity")
        try Self.check(previewDelay, in: CustomizationLimits.delay, field: "previewDelay")
        try Self.check(previewWidth, in: CustomizationLimits.previewWidth, field: "previewWidth")
        try Self.check(previewHeight, in: CustomizationLimits.previewHeight, field: "previewHeight")
        try Self.check(previewTitleFontSize, in: CustomizationLimits.fontSize, field: "previewTitleFontSize")
        try Self.check(startMenuWidth, in: CustomizationLimits.startMenuWidth, field: "startMenuWidth")
        try Self.check(startMenuHeight, in: CustomizationLimits.startMenuHeight, field: "startMenuHeight")
        try Self.check(startMenuFontSize, in: CustomizationLimits.fontSize, field: "startMenuFontSize")
        try Self.check(startMenuIconSize, in: CustomizationLimits.iconSize, field: "startMenuIconSize")
        try Self.check(autoHideDelay, in: CustomizationLimits.delay, field: "autoHideDelay")
        try Self.check(revealDelay, in: CustomizationLimits.delay, field: "revealDelay")
        try Self.check(revealStrip, in: CustomizationLimits.revealStrip, field: "revealStrip")
        try Self.check(animationDuration, in: CustomizationLimits.animationDuration, field: "animationDuration")
        guard hiddenDisplayIDs.count <= 32, Set(hiddenDisplayIDs).count == hiddenDisplayIDs.count else {
            throw PreferencesError.invalidValue(field: "hidden displays", reason: "use at most 32 unique display identifiers")
        }
    }

    private static func check(_ value: Double, in range: ClosedRange<Double>, field: String) throws {
        guard value.isFinite, range.contains(value) else {
            throw PreferencesError.invalidValue(field: field, reason: "use a value from \(range.lowerBound) to \(range.upperBound)")
        }
    }
}
