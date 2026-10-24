import ApplicationServices
import Foundation

/// Worker-confined standard AppKit tabs. Identity is the retained AX tab/group,
/// never its label, index or (shared) CGWindowID. Browser content tabs are excluded.
final class NativeTabService {
    private struct Tab {
        let pid: Int32
        let group: AXUIElement
        let button: AXUIElement
    }
    private var retained: [UInt32: Tab] = [:]
    private var nextToken: UInt32 = 0x8000_0000
    var knownIDs: [String] { retained.keys.map(String.init) }

    func entries(_ windows: [(WindowEntry, AXUIElement)], enabled: Bool) -> [WindowEntry] {
        guard enabled else { retained.removeAll(); return windows.map(\.0) }
        var live: [UInt32: Tab] = [:]
        var result: [WindowEntry] = []
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        var claimedGroups: [(Int32, AXUIElement)] = []
        for (window, element) in windows.sorted(by: {
            if $0.0.isFocused != $1.0.isFocused { return $0.0.isFocused }
            return $0.0.isOnScreen && !$1.0.isOnScreen
        }) {
            guard ProcessInfo.processInfo.systemUptime < deadline else { result.append(window); continue }
            let groups = children(element).filter {
                ProcessInfo.processInfo.systemUptime < deadline && string($0, kAXRoleAttribute) == "AXTabGroup"
            }
            guard !window.isDialog, groups.count == 1, let group = groups.first,
                  owner(group) == window.pid else { result.append(window); continue }
            let buttons = children(group).filter { ProcessInfo.processInfo.systemUptime < deadline && isTab($0, pid: window.pid) }
            guard ProcessInfo.processInfo.systemUptime < deadline else { result.append(window); continue }
            guard buttons.count > 1, buttons.count <= 128 else { result.append(window); continue }
            if claimedGroups.contains(where: { $0.0 == window.pid && CFEqual($0.1, group) }) { continue }
            let resultStart = result.count
            var groupTokens: [UInt32] = []
            for button in buttons {
                guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                let record = Tab(pid: window.pid, group: group, button: button)
                let token: UInt32
                if let previous = retained.first(where: { same($0.value, record) }) {
                    token = previous.key
                } else {
                    guard nextToken != 0 else { continue }
                    token = nextToken; nextToken &+= 1
                }
                live[token] = record
                groupTokens.append(token)
                let selected = selected(button)
                result.append(WindowEntry(id: token, pid: window.pid,
                    title: string(button, kAXTitleAttribute) ?? window.title,
                    appName: window.appName, bundleIdentifier: window.bundleIdentifier,
                    bounds: window.bounds, isMinimized: window.isMinimized,
                    isOnScreen: window.isOnScreen, isDialog: false,
                    isFocused: window.isFocused && selected, isHidden: window.isHidden,
                    isFullscreen: window.isFullscreen,
                    captureWindowID: selected ? window.captureWindowID : nil,
                    isOnCurrentSpace: window.isOnCurrentSpace, isOnAllSpaces: window.isOnAllSpaces,
                    isNativeTab: true))
            }
            if result.count - resultStart == buttons.count {
                claimedGroups.append((window.pid, group))
            } else {
                result.removeLast(result.count - resultStart)
                for token in groupTokens { live.removeValue(forKey: token) }
                result.append(window)
            }
        }
        retained = live
        return result
    }

    /// The selected tab changes AXWindows' root. Resolve through the exact same
    /// group/button on every action, rather than keeping yesterday's host root.
    func window(for entry: WindowEntry, in windows: [AXUIElement]) -> AXUIElement? {
        guard let tab = retained[entry.id], tab.pid == entry.pid,
              isTab(tab.button, pid: entry.pid), owner(tab.group) == entry.pid else { return nil }
        let matches = windows.filter { window in
            owner(window) == entry.pid && children(window).contains { CFEqual($0, tab.group) } &&
                children(tab.group).contains { CFEqual($0, tab.button) }
        }
        return matches.count == 1 ? matches.first : nil
    }

    func isSelected(_ entry: WindowEntry) -> Bool {
        retained[entry.id].map { selected($0.button) } ?? false
    }

    func select(_ entry: WindowEntry) -> Bool {
        guard let tab = retained[entry.id], tab.pid == entry.pid, isTab(tab.button, pid: entry.pid) else { return false }
        AXUIElementSetMessagingTimeout(tab.button, 0.5)
        let result = AXUIElementPerformAction(tab.button, kAXPressAction as CFString)
        // AppKit may apply a tab selection while its AX reply times out. The
        // caller always verifies selection and the new host; it never re-presses.
        return result == .success || result == .cannotComplete
    }

    func close(_ entry: WindowEntry, application: AXUIElement, expectedWindow: AXUIElement) -> AXError {
        guard let tab = retained[entry.id], tab.pid == entry.pid, isTab(tab.button, pid: entry.pid),
              selected(tab.button), let focused = element(application, kAXFocusedWindowAttribute),
              CFEqual(focused, expectedWindow) else { return .invalidUIElement }
        // macOS 27 can acknowledge AXPress on a tab's close affordance without
        // closing it. Prefer the explicit native Close Tab menu command when its
        // English label and unmodified Command-W binding both verify its meaning.
        // Never use Close Window, Close Other Tabs, or a synthetic keyboard event.
        if let command = closeTabCommand(application, pid: entry.pid), selected(tab.button),
           let focused = element(application, kAXFocusedWindowAttribute), CFEqual(focused, expectedWindow) {
            AXUIElementSetMessagingTimeout(command, 0.5)
            return AXUIElementPerformAction(command, kAXPressAction as CFString)
        }
        // Standard AppKit AXTabButton exposes its own sole direct close button.
        // Never fall back to the window traffic light or an app keyboard shortcut.
        let buttons = children(tab.button).filter { string($0, kAXRoleAttribute) == kAXButtonRole && owner($0) == entry.pid }
        guard buttons.count == 1, let close = buttons.first else { return .actionUnsupported }
        AXUIElementSetMessagingTimeout(close, 0.5)
        return AXUIElementPerformAction(close, kAXPressAction as CFString)
    }

    private func closeTabCommand(_ application: AXUIElement, pid: Int32) -> AXUIElement? {
        guard let bar = element(application, kAXMenuBarAttribute) else { return nil }
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        var matches: [AXUIElement] = []
        for top in children(bar) {
            guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
            for menu in children(top) {
                guard string(menu, kAXRoleAttribute) == kAXMenuRole else { continue }
                for item in children(menu) {
                    guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
                    guard owner(item) == pid, string(item, kAXRoleAttribute) == kAXMenuItemRole,
                          string(item, kAXTitleAttribute) == "Close Tab",
                          string(item, "AXMenuItemCmdChar")?.uppercased() == "W",
                          (attribute(item, "AXMenuItemCmdModifiers") as? NSNumber)?.intValue == 0,
                          (attribute(item, kAXEnabledAttribute) as? NSNumber)?.boolValue == true else { continue }
                    matches.append(item)
                }
            }
        }
        return matches.count == 1 ? matches.first : nil
    }
    private func element(_ e: AXUIElement, _ key: String) -> AXUIElement? {
        guard let value = attribute(e, key), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func same(_ a: Tab, _ b: Tab) -> Bool { a.pid == b.pid && CFEqual(a.group, b.group) && CFEqual(a.button, b.button) }
    private func isTab(_ e: AXUIElement, pid: Int32) -> Bool {
        owner(e) == pid && string(e, kAXRoleAttribute) == "AXRadioButton" && string(e, kAXSubroleAttribute) == "AXTabButton"
    }
    private func selected(_ e: AXUIElement) -> Bool { (attribute(e, kAXValueAttribute) as? NSNumber)?.boolValue == true }
    private func owner(_ e: AXUIElement) -> Int32? { var pid: pid_t = 0; return AXUIElementGetPid(e, &pid) == .success ? pid : nil }
    private func string(_ e: AXUIElement, _ key: String) -> String? { attribute(e, key) as? String }
    private func attribute(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(e, 0.05)
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, key as CFString, &value) == .success ? value : nil
    }
    private func children(_ e: AXUIElement) -> [AXUIElement] {
        guard let values = attribute(e, kAXChildrenAttribute) as? [AnyObject], values.count <= 256,
              values.allSatisfy({ CFGetTypeID($0) == AXUIElementGetTypeID() }) else { return [] }
        return values.map { unsafeBitCast($0, to: AXUIElement.self) }
    }
}
