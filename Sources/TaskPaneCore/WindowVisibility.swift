import Foundation

public enum WindowVisibility {
    /// Space assignment alone is not evidence of a visible user window. Unknown
    /// membership keeps the public visibility fallback; an explicit off-screen
    /// override includes every otherwise eligible discovered window.
    public static func admits(showOffscreen: Bool, onCurrentSpace: Bool?, onScreen: Bool,
                              minimized: Bool, hidden: Bool) -> Bool {
        showOffscreen || (onCurrentSpace != false && (onScreen || minimized || hidden))
    }
}
