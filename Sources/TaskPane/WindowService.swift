import AppKit
import ApplicationServices
import Combine
import CoreGraphics

struct WindowEntry: Identifiable, Sendable {
    /// A TaskPane session token, never a CGWindowID or a title-derived identity.
    let id: UInt32
    let pid: Int32
    let title: String
    let appName: String
    let bundleIdentifier: String?
    let bounds: CGRect
    let isMinimized: Bool
    /// Best-effort CG visibility hint. It does not establish a window's Space.
    let isOnScreen: Bool
    let isDialog: Bool
    let isFocused: Bool

    init(id: UInt32, pid: Int32, title: String, appName: String,
         bundleIdentifier: String?, bounds: CGRect, isMinimized: Bool,
         isOnScreen: Bool, isDialog: Bool = false, isFocused: Bool = false) {
        self.id = id
        self.pid = pid
        self.title = title
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.isOnScreen = isOnScreen
        self.isDialog = isDialog
        self.isFocused = isFocused
    }
}

struct RunningAppEntry: Identifiable, Sendable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let url: URL?
}

/// Only verified Accessibility windows become rows. CG records cannot create a
/// row or identify an action target; titles and geometry are presentation data.
@MainActor
final class WindowService: ObservableObject {
    @Published var windows: [WindowEntry] = []
    @Published var apps: [RunningAppEntry] = []
    @Published var recentApplicationPIDs: [Int32] = []
    @Published var accessibilityGranted = false
    @Published var lastActionMessage: String?

    private let worker = DispatchQueue(label: "app.taskpane.window-inspection", qos: .userInitiated)
    private let inspector = WindowInspector()
    private let workState = WindowWorkState()
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var refreshInProgress = false
    private var refreshRequested = false
    private var stopped = false
    private var lifecycle = UUID()
    private let permissionGuide = "Enable TaskPane in System Settings → Privacy & Security → Accessibility (Device Control and Data Access on macOS 27)."

    init() {
        accessibilityGranted = AXIsProcessTrusted()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let workspaceEvents: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]
        for event in workspaceEvents {
            let token = workspaceCenter.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            observers.append((workspaceCenter, token))
        }
        let center = NotificationCenter.default
        let token = center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        observers.append((center, token))

        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    deinit {
        workState.stop()
        timer?.invalidate()
        for (center, token) in observers { center.removeObserver(token) }
    }

    func stop() {
        stopped = true
        workState.stop()
        lifecycle = UUID()
        timer?.invalidate()
        timer = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }

    func refresh() {
        guard !stopped else { return }
        let wasGranted = accessibilityGranted
        accessibilityGranted = AXIsProcessTrusted()
        if !wasGranted, accessibilityGranted, lastActionMessage == permissionGuide {
            lastActionMessage = nil
        }
        if refreshInProgress {
            refreshRequested = true
            return
        }
        refreshInProgress = true
        let trusted = accessibilityGranted
        let currentLifecycle = lifecycle
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSWorkspace.shared.runningApplications.compactMap { application -> RunningAppEntry? in
            guard application.processIdentifier != ownPID,
                  application.activationPolicy == .regular,
                  !application.isTerminated else { return nil }
            return RunningAppEntry(
                pid: application.processIdentifier,
                name: application.localizedName ?? application.bundleURL?.deletingPathExtension().lastPathComponent ?? "Application",
                bundleIdentifier: application.bundleIdentifier,
                url: application.bundleURL
            )
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.pid < $1.pid : comparison == .orderedAscending
        }
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let runningPIDs = Set(runningApps.map(\.pid))
        var recent = recentApplicationPIDs.filter { runningPIDs.contains($0) }
        if let frontmostPID, runningPIDs.contains(frontmostPID) {
            recent.removeAll { $0 == frontmostPID }
            recent.insert(frontmostPID, at: 0)
        }
        recent = Array(recent.prefix(50))
        if recent != recentApplicationPIDs { recentApplicationPIDs = recent }

        let inspector = inspector
        let workState = workState
        worker.async { [weak self] in
            guard workState.isActive else { return }
            let entries = inspector.enumerate(apps: runningApps, trusted: trusted, frontmostPID: frontmostPID)
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.stopped, self.lifecycle == currentLifecycle else { return }
                self.apps = runningApps
                self.windows = entries
                self.refreshInProgress = false
                if self.refreshRequested {
                    self.refreshRequested = false
                    self.refresh()
                }
            }
        }
    }

    /// Called only by an explicit onboarding/settings button.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        lastActionMessage = accessibilityGranted ? "Accessibility access is enabled." : permissionGuide
        refresh()
    }

    func activate(_ entry: WindowEntry) {
        guard !stopped else { return }
        accessibilityGranted = AXIsProcessTrusted()
        guard accessibilityGranted else {
            activateApp(pid: entry.pid)
            if lastActionMessage == nil {
                lastActionMessage = "Activated \(entry.appName). Enable Accessibility to select an individual window."
            }
            return
        }
        perform(.activate, entry: entry)
    }

    func click(_ entry: WindowEntry, secondClickMinimizes: Bool) {
        guard !stopped else { return }
        accessibilityGranted = AXIsProcessTrusted()
        guard accessibilityGranted else { activate(entry); return }
        perform(.click(secondClickMinimizes: secondClickMinimizes), entry: entry)
    }

    func minimize(_ entry: WindowEntry) { perform(.minimize, entry: entry) }
    func close(_ entry: WindowEntry) { perform(.close, entry: entry) }

    /// Cached rendering hint only. click() performs its own fresh focus check on
    /// the worker; this method does no AX IPC and never accesses the registry.
    func isFocused(_ entry: WindowEntry) -> Bool {
        guard !stopped,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == entry.pid else { return false }
        return windows.first(where: { $0.id == entry.id && $0.pid == entry.pid })?.isFocused ?? false
    }

    func activateApp(pid: Int32) {
        guard !stopped else { return }
        guard let application = validApplication(pid: pid) else {
            lastActionMessage = "This application has closed."
            refresh()
            return
        }
        // Raising the verified AX window can already put its owner in front.
        // Report the achieved state even when a redundant activation returns false.
        if application.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
            lastActionMessage = nil
            return
        }
        let activated = application.activate(options: [])
        let isFrontmost = application.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        lastActionMessage = activated || isFrontmost ? nil : "macOS could not activate this application."
    }

    private func validApplication(pid: Int32) -> NSRunningApplication? {
        guard pid != ProcessInfo.processInfo.processIdentifier,
              let application = NSRunningApplication(processIdentifier: pid),
              application.activationPolicy == .regular,
              !application.isTerminated else { return nil }
        return application
    }

    private func perform(_ action: WindowInspector.Action, entry: WindowEntry) {
        guard !stopped else { return }
        accessibilityGranted = AXIsProcessTrusted()
        guard accessibilityGranted else {
            lastActionMessage = "Enable Accessibility to control an individual window."
            return
        }
        guard validApplication(pid: entry.pid) != nil else {
            lastActionMessage = "This application has closed."
            refresh()
            return
        }
        let currentLifecycle = lifecycle
        let inspector = inspector
        let workState = workState
        worker.async { [weak self] in
            guard workState.isActive else { return }
            let outcome = inspector.perform(action, entry: entry, workState: workState)
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.stopped, self.lifecycle == currentLifecycle else { return }
                if outcome.activateOwner {
                    // The selected retained element has already been resolved and
                    // raised. Only then ask macOS to activate its owning process.
                    self.activateApp(pid: entry.pid)
                } else {
                    self.lastActionMessage = outcome.message
                }
                self.refresh()
            }
        }
    }
}

/// This small cancellation flag can cross queues. AX objects and all identity
/// state below remain confined to WindowService's single serial worker queue.
private final class WindowWorkState: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    func stop() {
        lock.lock()
        active = false
        lock.unlock()
    }
}

private final class WindowInspector: @unchecked Sendable {
    enum Action: Sendable {
        case activate
        case minimize
        case close
        case click(secondClickMinimizes: Bool)
    }

    struct Outcome {
        let message: String?
        let activateOwner: Bool

        static func failure(_ message: String) -> Outcome {
            Outcome(message: message, activateOwner: false)
        }
        static let success = Outcome(message: nil, activateOwner: false)
        static let raised = Outcome(message: nil, activateOwner: true)
    }

    private struct RetainedWindow {
        let pid: Int32
        let element: AXUIElement
        let snapshot: WindowSnapshot
        let sampledAt: TimeInterval
    }

    private struct ApplicationInventory {
        let application: AXUIElement
        let elements: [AXUIElement]
    }

    private struct WindowSnapshot {
        let title: String?
        let bounds: CGRect
        let minimized: Bool
        let isDialog: Bool

        func settingMinimized(_ minimized: Bool) -> WindowSnapshot {
            WindowSnapshot(title: title, bounds: bounds, minimized: minimized, isDialog: isDialog)
        }
    }

    private enum SnapshotRead {
        case verified(WindowSnapshot)
        case unavailable
        case ineligible
    }

    private struct VisibilityHint {
        let pid: Int32
        let title: String?
        let bounds: CGRect
    }

    private var retained: [UInt32: RetainedWindow] = [:]
    private var nextToken: UInt32 = 1
    private var inspectionStartIndex = 0
    private var windowInspectionOffsets: [Int32: Int] = [:]
    private let maximumWindowsPerApplication = 256
    private let maximumCachedSnapshotAge: TimeInterval = 12
    private let actionTimeout: Float = 1

    func enumerate(apps: [RunningAppEntry], trusted: Bool, frontmostPID: Int32?) -> [WindowEntry] {
        guard trusted, AXIsProcessTrusted() else {
            retained.removeAll()
            return []
        }
        let runningPIDs = Set(apps.map(\.pid))
        retained = retained.filter { runningPIDs.contains($0.value.pid) }
        windowInspectionOffsets = windowInspectionOffsets.filter { runningPIDs.contains($0.key) }
        let hints = Dictionary(grouping: visibilityHints(), by: \.pid)
        // Membership is independent of the metadata budget. A slow early app
        // must not make later apps disappear merely because the sweep ended.
        let start = apps.isEmpty ? 0 : inspectionStartIndex % apps.count
        let orderedApps = Array(apps.dropFirst(start)) + Array(apps.prefix(start))
        inspectionStartIndex = apps.isEmpty ? 0 : (start + 1) % apps.count
        var inventories: [(RunningAppEntry, ApplicationInventory)] = []
        for app in orderedApps {
            guard let inventory = applicationWindows(pid: app.pid, timeout: 0.25) else { continue }
            retained = retained.filter { _, record in
                record.pid != app.pid || inventory.elements.contains { CFEqual($0, record.element) }
            }
            inventories.append((app, inventory))
        }

        let metadataDeadline = ProcessInfo.processInfo.systemUptime + 2
        var nextInspectionPID: Int32?
        var entries: [WindowEntry] = []

        for (app, inventory) in inventories {
            if nextInspectionPID == nil, ProcessInfo.processInfo.systemUptime >= metadataDeadline {
                nextInspectionPID = app.pid
            }
            // One slow Accessibility server must not consume the entire sweep.
            let appDeadline = min(metadataDeadline, ProcessInfo.processInfo.systemUptime + 0.4)
            let focused = app.pid == frontmostPID
                ? elementAttribute(inventory.application, kAXFocusedWindowAttribute, timeout: 0.05) : nil
            let windowCount = inventory.elements.count
            let windowStart = windowCount == 0 ? 0 : (windowInspectionOffsets[app.pid] ?? 0) % windowCount
            let orderedElements = Array(inventory.elements.dropFirst(windowStart)) + Array(inventory.elements.prefix(windowStart))
            for (offset, element) in orderedElements.enumerated() {
                guard owner(of: element) == app.pid else { continue }
                let previous = retained.first { $0.value.pid == app.pid && CFEqual($0.value.element, element) }
                let hasMetadataBudget = ProcessInfo.processInfo.systemUptime < appDeadline
                let read = hasMetadataBudget ? readSnapshot(of: element, timeout: 0.15) : .unavailable
                if hasMetadataBudget {
                    windowInspectionOffsets[app.pid] = (windowStart + offset + 1) % windowCount
                }
                let snapshot: WindowSnapshot
                let sampledAt: TimeInterval
                switch read {
                case .verified(let fresh):
                    snapshot = fresh
                    sampledAt = ProcessInfo.processInfo.systemUptime
                case .unavailable:
                    // Cached presentation is allowed only for this exact member
                    // of a successfully fetched, current AXWindows list. Reuse
                    // never extends its age, and no failed list emits old rows.
                    guard let previous,
                          ProcessInfo.processInfo.systemUptime - previous.value.sampledAt <= maximumCachedSnapshotAge else { continue }
                    snapshot = previous.value.snapshot
                    sampledAt = previous.value.sampledAt
                case .ineligible:
                    if let previous { retained.removeValue(forKey: previous.key) }
                    continue
                }
                guard let token = token(for: element, pid: app.pid, snapshot: snapshot, sampledAt: sampledAt) else { continue }
                let isFocused = focused.map { CFEqual($0, element) } == true && app.pid == frontmostPID
                let onScreen = !snapshot.minimized && (isFocused || (hints[app.pid] ?? []).contains {
                    Self.sameFrame($0.bounds, snapshot.bounds) && Self.compatibleTitles($0.title, snapshot.title)
                })
                entries.append(WindowEntry(
                    id: token, pid: app.pid, title: snapshot.title ?? app.name,
                    appName: app.name, bundleIdentifier: app.bundleIdentifier,
                    bounds: snapshot.bounds, isMinimized: snapshot.minimized,
                    isOnScreen: onScreen, isDialog: snapshot.isDialog, isFocused: isFocused
                ))
            }
        }
        if let nextInspectionPID, let index = apps.firstIndex(where: { $0.pid == nextInspectionPID }) {
            inspectionStartIndex = index
        }
        return entries.sorted {
            let appComparison = $0.appName.localizedStandardCompare($1.appName)
            if appComparison != .orderedSame { return appComparison == .orderedAscending }
            let titleComparison = $0.title.localizedStandardCompare($1.title)
            return titleComparison == .orderedSame ? $0.id < $1.id : titleComparison == .orderedAscending
        }
    }

    func perform(_ requestedAction: Action, entry: WindowEntry, workState: WindowWorkState) -> Outcome {
        guard workState.isActive else { return .failure("Window inspection stopped.") }
        guard AXIsProcessTrusted() else {
            return .failure("Accessibility access was removed. Enable it to control windows.")
        }
        guard let record = retained[entry.id], record.pid == entry.pid else {
            return .failure("This window is no longer in the verified list. Refresh and try again.")
        }
        guard let inventory = applicationWindows(pid: entry.pid, timeout: actionTimeout) else {
            return .failure("This application did not provide a complete window list. No action was sent; try again.")
        }
        // Exact AX object membership is the action identity. Never substitute a
        // similarly named, positioned, minimized, or newly created window.
        guard inventory.elements.contains(where: { CFEqual($0, record.element) }) else {
            retained.removeValue(forKey: entry.id)
            return .failure("The selected window has closed or is unavailable. No action was sent.")
        }
        guard let current = snapshot(of: record.element, timeout: actionTimeout),
              owner(of: record.element) == entry.pid else {
            return .failure("The selected window could not be verified. No action was sent.")
        }
        cache(current, for: entry.id, record: record)

        let action: Action
        if case .click(let secondClickMinimizes) = requestedAction {
            let focus = focusState(of: inventory.application, timeout: actionTimeout)
            if secondClickMinimizes, !current.minimized, focus.frontmost,
               let focused = focus.element, CFEqual(focused, record.element) {
                action = .minimize
            } else {
                action = .activate
            }
        } else {
            action = requestedAction
        }
        guard workState.isActive, AXIsProcessTrusted(), owner(of: record.element) == entry.pid else {
            return .failure("Window access changed. No action was sent.")
        }
        AXUIElementSetMessagingTimeout(record.element, actionTimeout)
        switch action {
        case .activate:
            if current.minimized {
                let restored = AXUIElementSetAttributeValue(record.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                guard restored == .success || booleanAttribute(record.element, kAXMinimizedAttribute, timeout: actionTimeout) == false else {
                    return .failure("macOS could not restore this window (Accessibility error \(restored.rawValue)).")
                }
                cache(current.settingMinimized(false), for: entry.id, record: record)
            }
            var raised = AXUIElementPerformAction(record.element, kAXRaiseAction as CFString)
            if current.minimized, raised == .cannotComplete {
                // Restore animation can outlast the first raise. This retry is
                // non-destructive, bounded, and revalidates exact membership.
                Thread.sleep(forTimeInterval: 0.12)
                guard workState.isActive, AXIsProcessTrusted(), owner(of: record.element) == entry.pid,
                      let fresh = applicationWindows(pid: entry.pid, timeout: actionTimeout),
                      fresh.elements.contains(where: { CFEqual($0, record.element) }) else {
                    return .failure("The restored window is no longer available. No further action was sent.")
                }
                AXUIElementSetMessagingTimeout(record.element, actionTimeout)
                raised = AXUIElementPerformAction(record.element, kAXRaiseAction as CFString)
            }
            return raised == .success ? .raised : .failure("macOS could not raise this window (Accessibility error \(raised.rawValue)).")
        case .minimize:
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(record.element, kAXMinimizedAttribute as CFString, &settable) == .success,
                  settable.boolValue else {
                return .failure("This application does not allow this window to be minimized.")
            }
            let result = AXUIElementSetAttributeValue(record.element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            if result == .success || booleanAttribute(record.element, kAXMinimizedAttribute, timeout: actionTimeout) == true {
                cache(current.settingMinimized(true), for: entry.id, record: record)
                return .success
            }
            return .failure("macOS could not minimize this window (Accessibility error \(result.rawValue)).")
        case .close:
            guard let button = elementAttribute(record.element, kAXCloseButtonAttribute, timeout: actionTimeout),
                  owner(of: button) == entry.pid else {
                return .failure("This window does not expose a verified close button. No close action was sent.")
            }
            AXUIElementSetMessagingTimeout(button, actionTimeout)
            let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
            return result == .success ? .success : .failure("macOS could not close this window (Accessibility error \(result.rawValue)).")
        case .click:
            return .failure("The window action could not be resolved.")
        }
    }

    private func cache(_ snapshot: WindowSnapshot, for token: UInt32, record: RetainedWindow) {
        retained[token] = RetainedWindow(pid: record.pid, element: record.element,
                                         snapshot: snapshot, sampledAt: ProcessInfo.processInfo.systemUptime)
    }

    private func token(for element: AXUIElement, pid: Int32, snapshot: WindowSnapshot, sampledAt: TimeInterval) -> UInt32? {
        if let existing = retained.first(where: { $0.value.pid == pid && CFEqual($0.value.element, element) }) {
            retained[existing.key] = RetainedWindow(pid: pid, element: element, snapshot: snapshot, sampledAt: sampledAt)
            return existing.key
        }
        // Tokens are never recycled during this process, including after a close.
        guard nextToken != 0 else { return nil }
        let token = nextToken
        nextToken &+= 1
        retained[token] = RetainedWindow(pid: pid, element: element, snapshot: snapshot, sampledAt: sampledAt)
        return token
    }

    private func applicationWindows(pid: Int32, timeout: Float) -> ApplicationInventory? {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFArrayGetTypeID(),
              let raw = value as? [AnyObject], raw.count <= maximumWindowsPerApplication else { return nil }
        var elements: [AXUIElement] = []
        for value in raw {
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            let element = unsafeBitCast(value, to: AXUIElement.self)
            if !elements.contains(where: { CFEqual($0, element) }) { elements.append(element) }
        }
        return ApplicationInventory(application: application, elements: elements)
    }

    private func snapshot(of element: AXUIElement, timeout: Float) -> WindowSnapshot? {
        if case .verified(let snapshot) = readSnapshot(of: element, timeout: timeout) { return snapshot }
        return nil
    }

    private func readSnapshot(of element: AXUIElement, timeout: Float) -> SnapshotRead {
        AXUIElementSetMessagingTimeout(element, timeout)
        let attributes = [
            kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute,
            kAXPositionAttribute, kAXSizeAttribute, kAXMinimizedAttribute
        ] as CFArray
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, attributes, [], &values) == .success,
              let values = values as? [AnyObject], values.count == 6 else { return .unavailable }
        guard let role = values[0] as? String, let subrole = values[1] as? String else { return .unavailable }
        let dialog = subrole == "AXDialog" || subrole == "AXSystemDialog"
        guard role == kAXWindowRole, subrole == kAXStandardWindowSubrole || dialog else { return .ineligible }
        guard
              let position = Self.point(from: values[3]), let size = Self.size(from: values[4]),
              let minimized = (values[5] as? NSNumber)?.boolValue,
              position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return .unavailable }
        return .verified(WindowSnapshot(
            title: Self.nonempty(values[2] as? String), bounds: CGRect(origin: position, size: size),
            minimized: minimized, isDialog: dialog
        ))
    }

    private func focusState(of application: AXUIElement, timeout: Float) -> (frontmost: Bool, element: AXUIElement?) {
        AXUIElementSetMessagingTimeout(application, timeout)
        let attributes = [kAXFrontmostAttribute, kAXFocusedWindowAttribute] as CFArray
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(application, attributes, [], &values) == .success,
              let values = values as? [AnyObject], values.count == 2 else { return (false, nil) }
        let focused = CFGetTypeID(values[1]) == AXUIElementGetTypeID()
            ? unsafeBitCast(values[1], to: AXUIElement.self) : nil
        return ((values[0] as? NSNumber)?.boolValue ?? false, focused)
    }

    private func booleanAttribute(_ element: AXUIElement, _ attribute: String, timeout: Float) -> Bool? {
        AXUIElementSetMessagingTimeout(element, timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String, timeout: Float) -> AXUIElement? {
        AXUIElementSetMessagingTimeout(element, timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func owner(of element: AXUIElement) -> Int32? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    private func visibilityHints() -> [VisibilityHint] {
        guard let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        return records.compactMap { record in
            guard let owner = record[kCGWindowOwnerPID as String] as? NSNumber,
                  let layer = record[kCGWindowLayer as String] as? NSNumber, layer.intValue == 0,
                  let dictionary = record[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary),
                  bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                  bounds.width.isFinite, bounds.height.isFinite,
                  bounds.width > 0, bounds.height > 0 else { return nil }
            return VisibilityHint(pid: owner.int32Value,
                                  title: Self.nonempty(record[kCGWindowName as String] as? String), bounds: bounds)
        }
    }

    private static func compatibleTitles(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = nonempty(lhs), let rhs = nonempty(rhs) else { return true }
        return lhs == rhs
    }

    private static func sameFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 2 && abs(lhs.minY - rhs.minY) <= 2 &&
        abs(lhs.width - rhs.width) <= 2 && abs(lhs.height - rhs.height) <= 2
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func point(from value: AnyObject) -> CGPoint? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var result = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &result) ? result : nil
    }

    private static func size(from value: AnyObject) -> CGSize? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var result = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &result) ? result : nil
    }
}
