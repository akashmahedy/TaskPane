import AppKit
import Combine
import SwiftUI
import TaskPaneCore

@MainActor
final class TaskbarCoordinator {
    private let settings: SettingsStore
    private let metrics: MetricsService
    private let windows: WindowService
    private let showSettings: () -> Void
    private let showLauncher: () -> Void
    private var panels: [NSPanel] = []
    private var subscriptions = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?
    private var lastLayoutKey = ""
    private var hideTimer: Timer?
    private var fullFrames: [NSRect] = []
    private var lastPointerInside: [ObjectIdentifier: Date] = [:]

    init(settings: SettingsStore, metrics: MetricsService, windows: WindowService,
         showSettings: @escaping () -> Void, showLauncher: @escaping () -> Void) {
        self.settings = settings; self.metrics = metrics; self.windows = windows
        self.showSettings = showSettings; self.showLauncher = showLauncher
        settings.$preferences.sink { [weak self] preferences in self?.layout(preferences) }.store(in: &subscriptions)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.lastLayoutKey = ""; self?.layout(self?.settings.preferences ?? TaskPanePreferences()) }
        }
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateAutoHide() }
        }
    }

    deinit {
        hideTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func close() {
        panels.forEach { $0.close() }
        panels.removeAll()
        fullFrames.removeAll()
        lastPointerInside.removeAll()
    }

    private func layout(_ preferences: TaskPanePreferences) {
        let custom = preferences.layout
        let key = "\(preferences.appMode.rawValue)-\(preferences.barEdge.rawValue)-\(preferences.barHeight)-\(preferences.showOnAllDisplays)-\(custom.itemHeight)-\(custom.lengthPercent)-\(custom.alignment.rawValue)-\(custom.edgeOffset)-\(custom.alongEdgeOffset)"
        guard lastLayoutKey != key else { return }
        lastLayoutKey = key
        close()
        guard preferences.appMode != .menubar else { return }
        let screens = preferences.showOnAllDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        for screen in screens {
            let frame = screen.visibleFrame
            let vertical = preferences.barEdge == .left || preferences.barEdge == .right
            let thickness = CGFloat(max(preferences.barHeight, custom.itemHeight + 12))
            let inset = CGFloat(custom.edgeOffset)
            let dimension = vertical ? frame.height : frame.width
            let length = max(120, dimension * CGFloat(custom.lengthPercent / 100))
            let origin = vertical ? frame.minY : frame.minX
            let start: CGFloat
            switch custom.alignment {
            case .leading: start = origin
            case .center: start = origin + (dimension - length) / 2
            case .trailing: start = origin + dimension - length
            }
            let along = min(origin + dimension - length, max(origin, start + CGFloat(custom.alongEdgeOffset)))
            let rect: NSRect
            switch preferences.barEdge {
            case .bottom: rect = NSRect(x: along, y: frame.minY + inset, width: length, height: thickness)
            case .top: rect = NSRect(x: along, y: frame.maxY - thickness - inset, width: length, height: thickness)
            case .left: rect = NSRect(x: frame.minX + inset, y: along, width: thickness, height: length)
            case .right: rect = NSRect(x: frame.maxX - thickness - inset, y: along, width: thickness, height: length)
            }
            let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "TaskPane Taskbar"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: TaskbarView(settings: settings, metrics: metrics, windows: windows,
                                                                  displayBounds: CGDisplayBounds(screenID), vertical: vertical,
                                                                  showSettings: showSettings, showLauncher: showLauncher))
            panel.orderFrontRegardless()
            panels.append(panel)
            fullFrames.append(rect)
            lastPointerInside[ObjectIdentifier(panel)] = Date()
        }
    }

    private func updateAutoHide() {
        let point = NSEvent.mouseLocation
        for (index, panel) in panels.enumerated() where fullFrames.indices.contains(index) {
            let full = fullFrames[index]
            let identifier = ObjectIdentifier(panel)
            if panel.frame.contains(point) { lastPointerInside[identifier] = Date() }
            let lastInside = lastPointerInside[identifier] ?? .distantPast
            let reveal = !settings.preferences.autoHide || panel.frame.contains(point) || Date().timeIntervalSince(lastInside) < 0.7
            var target = full
            if !reveal {
                switch settings.preferences.barEdge {
                case .bottom: target.size.height = 5
                case .top: target.origin.y = full.maxY - 5; target.size.height = 5
                case .left: target.size.width = 5
                case .right: target.origin.x = full.maxX - 5; target.size.width = 5
                }
            }
            if panel.frame != target {
                let animate = !settings.preferences.reduceMotion && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                panel.setFrame(target, display: true, animate: animate)
            }
        }
    }
}
