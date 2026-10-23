import AppKit
import Combine
import SwiftUI
import TaskPaneCore

@main
struct TaskPaneMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--diagnose") { TaskPaneDiagnostics.run(); return }
        let app = NSApplication.shared
        let delegate = TaskPaneAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class TaskPaneAppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    let metrics = MetricsService()
    let windows = WindowService()
    let launcher = LauncherService()
    private var settingsWindow: NSWindow?
    private var launcherWindow: NSWindow?
    private var bars: TaskbarCoordinator?
    private var statusItem: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()
    private var lastInterval: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        bars = TaskbarCoordinator(settings: settings, metrics: metrics, windows: windows, launcher: launcher,
                                  showSettings: { [weak self] in self?.showSettings() })
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(withTitle: "Open TaskPane", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Application launcher", action: #selector(showLauncher), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Refresh windows", action: #selector(refreshWindows), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TaskPane", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem?.menu = menu
        settings.$preferences.combineLatest(metrics.$snapshot).sink { [weak self] preferences, snapshot in
            guard let self else { return }
            self.updateStatusItem(preferences, snapshot)
            if self.lastInterval != preferences.refreshInterval {
                self.lastInterval = preferences.refreshInterval
                self.metrics.setInterval(preferences.refreshInterval)
            }
            self.updateAppearance(preferences.theme)
        }.store(in: &subscriptions)
        showSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        settings.saveNow()
        metrics.stop()
        windows.stop()
        bars?.close()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let root = SettingsView(settings: settings, metrics: metrics, windows: windows, launcher: launcher)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "TaskPane"
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: root)
            window.minSize = NSSize(width: 940, height: 650)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func showLauncher() {
        if launcherWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 630),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "TaskPane Launcher"
            window.contentView = NSHostingView(rootView: LauncherView(launcher: launcher, settings: settings))
            window.minSize = NSSize(width: 480, height: 400)
            window.isReleasedWhenClosed = false
            window.center()
            launcherWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        launcherWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func refreshWindows() { windows.refresh() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateAppearance(_ theme: ThemeMode) {
        switch theme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func updateStatusItem(_ preferences: TaskPanePreferences, _ snapshot: MetricSnapshot) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "TaskPane")
        button.imagePosition = .imageLeading
        let showMetrics = preferences.appMode != .taskbar
        let parts = preferences.widgets.filter { showMetrics && $0.placement.showsInMenubar }.map {
            MetricFormatting.text($0.kind, snapshot: snapshot, compact: $0.style == .compact)
        }
        button.title = parts.isEmpty ? "" : "  " + parts.joined(separator: "   ")
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.toolTip = "TaskPane • Created by akashmahedy • Click for settings and launcher"
    }

    private func configureMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "TaskPane Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit TaskPane", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"),
                                      ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"),
                                      ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        editItem.title = "Edit"
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
