import AppKit
import Combine
import SwiftUI
import TaskPaneCore

@MainActor
final class TaskbarCoordinator {
    private let settings: SettingsStore
    private let metrics: MetricsService
    private let windows: WindowService
    private let launcher: LauncherService
    private let showSettings: () -> Void
    private var panels: [NSPanel] = []
    private var subscriptions = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?
    private var lastLayoutKey = ""
    private var hideTimer: Timer?
    private var fullFrames: [NSRect] = []
    private var screenFrames: [NSRect] = []
    private var reservations: [WindowOverlapReservation] = []
    private var lastPointerInside: [ObjectIdentifier: Date] = [:]
    private var pointerEnteredAt: [ObjectIdentifier: Date] = [:]
    private var expandedPanels = Set<ObjectIdentifier>()
    private lazy var overlaps = WindowOverlapService(readState: { [weak self] entry in
        await self?.windows.readOverlapState(entry)
    }, setFrame: { [weak self] entry, target, expected in
        await self?.windows.setOverlapFrame(entry, frame: target, expectedFrame: expected)
    })

    init(settings: SettingsStore, metrics: MetricsService, windows: WindowService, launcher: LauncherService,
         showSettings: @escaping () -> Void) {
        self.settings = settings; self.metrics = metrics; self.windows = windows; self.launcher = launcher
        self.showSettings = showSettings
        settings.$preferences.sink { [weak self] preferences in
            guard let self else { return }
            self.layout(preferences)
            self.windows.configureSpaceTracking(enabled: preferences.options.nativeSpaceTracking)
            ApplicationBadgeService.shared.update(enabled: preferences.options.showAppBadges)
            if !preferences.options.hoverPreviewsEnabled { WindowPreviewService.shared.clear() }
            self.updateOverlap(preferences: preferences)
        }.store(in: &subscriptions)
        windows.$windows.sink { [weak self] entries in
            guard let self else { return }
            self.overlaps.update(enabled: self.settings.preferences.options.resizeOverlappingWindows && !self.settings.preferences.autoHide,
                                 windows: entries, reservations: self.reservations)
        }.store(in: &subscriptions)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.lastLayoutKey = ""; self.layout(self.settings.preferences); self.updateOverlap(preferences: self.settings.preferences)
            }
        }
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateAutoHide() }
        }
    }

    deinit {
        hideTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func prepareToClose() async { await overlaps.stop() }

    func close() {
        panels.forEach { $0.close() }
        panels.removeAll(); fullFrames.removeAll(); screenFrames.removeAll(); reservations.removeAll()
        lastPointerInside.removeAll(); pointerEnteredAt.removeAll(); expandedPanels.removeAll()
    }

    private func updateOverlap(preferences: TaskPanePreferences) {
        overlaps.update(enabled: preferences.options.resizeOverlappingWindows && !preferences.autoHide,
                        windows: windows.windows, reservations: reservations)
    }

    private func layout(_ preferences: TaskPanePreferences) {
        let custom = preferences.layout
        let options = preferences.options
        let key = "\(preferences.appMode)-\(preferences.barEdge)-\(preferences.barHeight)-\(preferences.showOnAllDisplays)-\(custom.itemHeight)-\(custom.lengthPercent)-\(custom.alignment)-\(custom.edgeOffset)-\(custom.alongEdgeOffset)-\(options.horizontalPadding)-\(options.verticalPadding)-\(options.useScreenFrame)-\(options.hiddenDisplayIDs)-\(options.barShadow)"
        guard lastLayoutKey != key else { return }
        lastLayoutKey = key
        close()
        guard preferences.appMode != .menubar else { return }
        let screens = preferences.showOnAllDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        for screen in screens {
            let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            guard !options.hiddenDisplayIDs.contains(screenID) else { continue }
            let frame = options.useScreenFrame ? screen.frame : screen.visibleFrame
            let vertical = preferences.barEdge == .left || preferences.barEdge == .right
            let rect = TaskbarGeometry.frame(in: frame, preferences: preferences)
            let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "TaskPane Taskbar"
            panel.isFloatingPanel = true; panel.level = .floating
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = options.barShadow
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel.isReleasedWhenClosed = false
            let identifier = ObjectIdentifier(panel)
            let host = NSHostingView(rootView: TaskbarView(settings: settings, metrics: metrics, windows: windows, launcher: launcher,
                displayBounds: CGDisplayBounds(screenID), vertical: vertical, showSettings: showSettings,
                interactionChanged: { [weak self] expanded in
                    if expanded { self?.expandedPanels.insert(identifier) }
                    else { self?.expandedPanels.remove(identifier); self?.lastPointerInside[identifier] = Date() }
                }))
            // The native clip container has no content minimum. Keeping the host
            // at full size allows a true 1–40pt strip without spilling to another display.
            host.sizingOptions = []
            host.frame = CGRect(origin: .zero, size: rect.size)
            let clip = NSView(frame: CGRect(origin: .zero, size: rect.size))
            clip.wantsLayer = true
            clip.layer?.masksToBounds = true
            clip.addSubview(host)
            panel.contentView = clip
            panel.minSize = .zero
            panel.contentMinSize = .zero
            panel.orderFrontRegardless()
            panels.append(panel); fullFrames.append(rect); screenFrames.append(screen.frame)
            let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
            let cgBar = CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
            reservations.append(WindowOverlapReservation(displayBounds: CGDisplayBounds(screenID), barBounds: cgBar, edge: preferences.barEdge))
            lastPointerInside[identifier] = Date()
        }
    }

    private func updateAutoHide() {
        let preferences = settings.preferences
        let options = preferences.options
        let point = NSEvent.mouseLocation
        for (index, panel) in panels.enumerated() where fullFrames.indices.contains(index) {
            let full = fullFrames[index]
            let screen = screenFrames[index]
            let identifier = ObjectIdentifier(panel)
            let fullscreen = options.hideInFullscreen && windows.windows.contains {
                $0.isFullscreen && $0.isOnScreen && reservations[index].displayBounds.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY))
            }
            if fullscreen { if panel.isVisible { panel.orderOut(nil) }; continue }
            if !panel.isVisible { panel.orderFrontRegardless() }
            let inside = panel.frame.contains(point)
            if inside {
                if pointerEnteredAt[identifier] == nil { pointerEnteredAt[identifier] = Date() }
                if panel.frame == full { lastPointerInside[identifier] = Date() }
            } else { pointerEnteredAt.removeValue(forKey: identifier) }
            let dwell = pointerEnteredAt[identifier].map { Date().timeIntervalSince($0) >= options.revealDelay } ?? false
            let recent = Date().timeIntervalSince(lastPointerInside[identifier] ?? .distantPast) < options.autoHideDelay
            let reveal = !preferences.autoHide || expandedPanels.contains(identifier) || (inside && (panel.frame == full || dwell)) || recent
            let target = reveal ? full : TaskbarGeometry.hiddenFrame(full, screen: screen, edge: preferences.barEdge, revealStrip: options.revealStrip)
            guard panel.frame != target else { continue }
            let animate = !preferences.reduceMotion && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && options.animationDuration > 0
            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = options.animationDuration
                    panel.animator().setFrame(target, display: true)
                }
            } else { panel.setFrame(target, display: true) }
        }
    }
}
