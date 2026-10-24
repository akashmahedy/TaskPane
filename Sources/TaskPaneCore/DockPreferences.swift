import Foundation

/// Only the three Dock keys explicitly managed by TaskPane. Nil preserves the
/// distinction between a missing preference and an explicitly stored default.
public struct DockPreferenceValues: Codable, Equatable {
    public var orientation: String?
    public var autoHide: Bool?
    public var revealDelay: Double?
    public init(orientation: String? = nil, autoHide: Bool? = nil, revealDelay: Double? = nil) {
        self.orientation = orientation; self.autoHide = autoHide; self.revealDelay = revealDelay
    }
    public static let suppressedRevealDelay: Double = 10_000_000_000
    public var fullyHidden: Bool { autoHide == true && (revealDelay ?? 0) >= Self.suppressedRevealDelay }
    public var isValid: Bool {
        (orientation.map { ["bottom", "left", "right"].contains($0) } ?? true) &&
        (revealDelay.map { $0.isFinite && $0 >= 0 } ?? true)
    }
    public func applying(orientation: String, autoHide: Bool, fullyHidden: Bool, original: Self?) -> Self {
        let normalDelay: Double?
        if let original { normalDelay = original.revealDelay }
        else { normalDelay = revealDelay }
        return Self(orientation: orientation, autoHide: fullyHidden || autoHide,
                    revealDelay: fullyHidden ? Self.suppressedRevealDelay : normalDelay)
    }
    /// Restore keys we still own, preserving independent edits made afterwards.
    public func restoring(original: Self, applied: Self) -> Self {
        Self(orientation: orientation == applied.orientation ? original.orientation : orientation,
             autoHide: autoHide == applied.autoHide ? original.autoHide : autoHide,
             revealDelay: revealDelay == applied.revealDelay ? original.revealDelay : revealDelay)
    }
}
