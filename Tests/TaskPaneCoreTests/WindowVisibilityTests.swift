import Testing
@testable import TaskPaneCore

struct WindowVisibilityTests {
    @Test func currentSpaceDoesNotAdmitAnInvisibleHelperWindow() {
        #expect(!WindowVisibility.admits(showOffscreen: false, onCurrentSpace: true,
                                        onScreen: false, minimized: false, hidden: false))
    }
    @Test func visibleWindowMustNotBeKnownToBelongToAnotherSpace() {
        #expect(WindowVisibility.admits(showOffscreen: false, onCurrentSpace: true,
                                       onScreen: true, minimized: false, hidden: false))
        #expect(!WindowVisibility.admits(showOffscreen: false, onCurrentSpace: false,
                                        onScreen: true, minimized: false, hidden: false))
        #expect(WindowVisibility.admits(showOffscreen: false, onCurrentSpace: nil,
                                       onScreen: true, minimized: false, hidden: false))
    }
    @Test func minimizedAndHiddenWindowsUseKnownSpaceOrVisibilityFallback() {
        #expect(WindowVisibility.admits(showOffscreen: false, onCurrentSpace: true,
                                       onScreen: false, minimized: true, hidden: false))
        #expect(WindowVisibility.admits(showOffscreen: false, onCurrentSpace: nil,
                                       onScreen: false, minimized: false, hidden: true))
        #expect(!WindowVisibility.admits(showOffscreen: false, onCurrentSpace: false,
                                        onScreen: false, minimized: true, hidden: true))
    }
    @Test func explicitOffscreenOverrideIncludesDiscoveredOtherSpaceWindows() {
        #expect(WindowVisibility.admits(showOffscreen: true, onCurrentSpace: false,
                                       onScreen: false, minimized: false, hidden: false))
    }
}
