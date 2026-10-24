import AppKit
import SwiftUI
import TaskPaneCore

extension WindowEntry {
    var arrangementKey: String { bundleIdentifier ?? "app:\(appName)" }
}

private struct StartButtonBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct TaskbarView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var metrics: MetricsService
    @ObservedObject var windows: WindowService
    @ObservedObject var launcher: LauncherService
    let displayBounds: CGRect
    let vertical: Bool
    let showSettings: () -> Void
    let interactionChanged: (Bool) -> Void
    @ViewState private var startPresented = false
    @ViewState private var previewGroups = Set<String>()
    @ViewState private var presentedGroups = Set<String>()
    private var preferences: TaskPanePreferences { settings.preferences }
    private var layout: LayoutCustomization { preferences.layout }
    private var options: TaskbarAdvancedOptions { preferences.options }
    private var iconOnlyWidth: Double { options.iconOnlyUsesItemHeight ? layout.itemHeight : options.iconOnlyWidth }
    private var iconSize: Double { min(preferences.iconSize, layout.itemHeight - 2) }

    private var visibleWindows: [WindowEntry] {
        arrangedWindows.filter { entry in
            (!preferences.currentDisplayOnly || displayBounds.contains(CGPoint(x: entry.bounds.midX, y: entry.bounds.midY))) &&
            (layout.showMinimizedWindows || !entry.isMinimized) &&
            (layout.showDialogs || !entry.isDialog) &&
            WindowVisibility.admits(showOffscreen: layout.showOffscreenWindows,
                                    onCurrentSpace: options.nativeSpaceTracking ? entry.isOnCurrentSpace : nil,
                                    onScreen: entry.isOnScreen, minimized: entry.isMinimized, hidden: entry.isHidden)
        }
    }
    /// Arrange before filtering so a hidden sibling cannot change its app's
    /// relative position when it becomes visible again.
    private var arrangedWindows: [WindowEntry] {
        let filtered = windows.windows.filter {
            !preferences.excludedBundleIdentifiers.contains($0.bundleIdentifier ?? "")
        }.sorted { lhs, rhs in
            if !layout.autoArrange {
                let a = layout.applicationOrder.firstIndex(of: lhs.arrangementKey) ?? Int.max
                let b = layout.applicationOrder.firstIndex(of: rhs.arrangementKey) ?? Int.max
                if a != b { return a < b }
            } else if layout.sortOrder == .recent {
                let a = windows.recentApplicationPIDs.firstIndex(of: lhs.pid) ?? Int.max
                let b = windows.recentApplicationPIDs.firstIndex(of: rhs.pid) ?? Int.max
                if a != b { return a < b }
            } else if layout.sortOrder == .title {
                let comparison = lhs.title.localizedStandardCompare(rhs.title)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            }
            if !layout.autoArrange { return lhs.id < rhs.id }
            let comparison = lhs.appName.localizedStandardCompare(rhs.appName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return lhs.id < rhs.id
        }
        let ids = WindowArrangement.ordered(
            items: filtered.map { WindowArrangementItem(id: String($0.id), applicationKey: $0.arrangementKey) },
            manualOrder: layout.autoArrange ? [] : windows.manualWindowOrder,
            groupAdjacent: preferences.grouping == .adjacent)
        let entries = Dictionary(uniqueKeysWithValues: filtered.map { (String($0.id), $0) })
        return ids.compactMap { entries[$0] }
    }
    private var applicationKeys: [String] {
        var seen = Set<String>()
        let keys = windows.accessibilityGranted ? visibleWindows.map(\.arrangementKey)
            : fallbackApplications.map { $0.bundleIdentifier ?? "app:\($0.name)" }
        return keys.filter { seen.insert($0).inserted }
    }
    private var fallbackApplications: [RunningAppEntry] {
        windows.apps.filter { !preferences.excludedBundleIdentifiers.contains($0.bundleIdentifier ?? "") }.sorted { lhs, rhs in
            if !layout.autoArrange {
                let a = layout.applicationOrder.firstIndex(of: lhs.bundleIdentifier ?? "app:\(lhs.name)") ?? Int.max
                let b = layout.applicationOrder.firstIndex(of: rhs.bundleIdentifier ?? "app:\(rhs.name)") ?? Int.max
                if a != b { return a < b }
            } else if layout.sortOrder == .recent {
                let a = windows.recentApplicationPIDs.firstIndex(of: lhs.pid) ?? Int.max
                let b = windows.recentApplicationPIDs.firstIndex(of: rhs.pid) ?? Int.max
                if a != b { return a < b }
            }
            let comparison = lhs.name.localizedStandardCompare(rhs.name)
            return comparison == .orderedSame ? lhs.pid < rhs.pid : comparison == .orderedAscending
        }
    }
    private func combinesWindows(available: CGFloat) -> Bool {
        if preferences.grouping == .always { return true }
        guard preferences.grouping == .automatic, applicationKeys.count < visibleWindows.count else { return false }
        let minimum = vertical ? layout.itemHeight : !preferences.showWindowTitles ? iconOnlyWidth
            : layout.itemSizing == .fixed ? layout.itemWidth : layout.minItemWidth
        let required = Double(visibleWindows.count) * minimum + Double(max(0, visibleWindows.count - 1)) * layout.itemSpacing
        return required > Double(available)
    }
    private var visibleWidgets: [TaskPaneCore.WidgetConfiguration] {
        preferences.widgets.filter { $0.placement.showsInTaskbar && ($0.kind != .clock || preferences.showClock) }
    }
    private var sections: [BarSection] {
        layout.sectionOrder.filter {
            switch $0 {
            case .launcher: return preferences.showLauncher
            case .pins: return !preferences.pinnedApplicationPaths.isEmpty
            case .widgets: return !visibleWidgets.isEmpty
            case .windows, .settings: return true
            }
        }
    }

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: options.sectionSpacing) {
                    ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                        if layout.showDividers && index > 0 { Divider() }
                        sectionContent(section)
                    }
                }.padding(.horizontal, options.horizontalPadding).padding(.vertical, options.verticalPadding)
            } else {
                HStack(spacing: options.sectionSpacing) {
                    ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                        if layout.showDividers && index > 0 { Divider().padding(.vertical, 7) }
                        sectionContent(section)
                    }
                }.padding(.horizontal, options.horizontalPadding).padding(.vertical, options.verticalPadding)
            }
        }
        .font(.system(size: min(preferences.fontSize, layout.itemHeight - 2)))
        .background(Color(nsColor: .windowBackgroundColor).opacity(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : preferences.barOpacity))
        .clipShape(RoundedRectangle(cornerRadius: layout.barCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: layout.barCornerRadius).stroke(Color.primary.opacity(options.barBorderOpacity), lineWidth: options.barBorderWidth))
        .tint(Color(taskPaneHex: preferences.accentHex))
        .accessibilityElement(children: .contain).accessibilityLabel("TaskPane taskbar")
        .contextMenu { taskbarCommands }
        .backgroundPreferenceValue(StartButtonBoundsKey.self) { anchor in
            startMenuPresenter(anchor: anchor)
        }
        .onChange(of: startPresented) { _, _ in interactionChanged(startPresented || !presentedGroups.isEmpty || !previewGroups.isEmpty) }
        .onChange(of: presentedGroups) { _, _ in interactionChanged(startPresented || !presentedGroups.isEmpty || !previewGroups.isEmpty) }
        .onChange(of: previewGroups) { _, _ in interactionChanged(startPresented || !presentedGroups.isEmpty || !previewGroups.isEmpty) }
        .onDisappear { interactionChanged(false) }
    }

    @ViewBuilder private func sectionContent(_ section: BarSection) -> some View {
        switch section {
        case .launcher:
            Button { startPresented.toggle() } label: {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: max(12, iconSize - 2), weight: .semibold))
                    .foregroundStyle(Color(taskPaneHex: preferences.accentHex)).frame(width: layout.itemHeight, height: layout.itemHeight)
            }.buttonStyle(.plain).help("Start · Search, pinned apps and recent apps").accessibilityLabel("Open Start menu")
                .anchorPreference(key: StartButtonBoundsKey.self, value: .bounds) { $0 }
        case .pins:
            if vertical { VStack(spacing: layout.itemSpacing) { pinButtons } }
            else { HStack(spacing: layout.itemSpacing) { pinButtons } }
        case .windows:
            GeometryReader { area in
                ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
                    if vertical {
                        VStack(spacing: layout.itemSpacing) {
                            windowButtons(width: nil, combined: combinesWindows(available: area.size.height))
                        }
                    } else {
                        let combined = combinesWindows(available: area.size.width)
                        HStack(spacing: layout.itemSpacing) { windowButtons(width: adaptiveWidth(area.size.width, combined: combined), combined: combined) }
                            .frame(minHeight: area.size.height)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .widgets:
            if vertical { VStack(spacing: layout.itemSpacing) { metricWidgets } }
            else { HStack(spacing: layout.itemSpacing + 2) { metricWidgets }.layoutPriority(1) }
        case .settings:
            Button(action: showSettings) {
                Image(systemName: "slider.horizontal.3").font(.system(size: min(18, iconSize))).frame(width: 26, height: layout.itemHeight)
            }.buttonStyle(.plain).help("TaskPane settings").accessibilityLabel("TaskPane settings")
        }
    }

    /// A single persistent presenter serves the button and the context command.
    /// When the button is hidden, the bar itself supplies the attachment bounds.
    private func startMenuPresenter(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { geometry in
            let bounds = anchor.map { geometry[$0] } ?? CGRect(origin: .zero, size: geometry.size)
            Color.clear
                .allowsHitTesting(false)
                .frame(width: max(1, bounds.width), height: max(1, bounds.height))
                .popover(isPresented: $startPresented, arrowEdge: startArrowEdge) {
                    StartMenuView(launcher: launcher, settings: settings,
                                  height: min(options.startMenuHeight, max(200, displayBounds.height - 120)),
                                  width: min(options.startMenuWidth, max(280, displayBounds.width - 40))) { startPresented = false }
                }
                .position(x: bounds.midX, y: bounds.midY)
        }
    }

    private var startArrowEdge: Edge {
        switch preferences.barEdge {
        case .bottom: return .bottom
        case .top: return .top
        case .left: return .leading
        case .right: return .trailing
        }
    }

    @ViewBuilder private var taskbarCommands: some View {
        Button("Start menu") { startPresented = true }
        Button("TaskPane settings…", action: showSettings)
        Button("Refresh windows") { windows.refresh() }
        Divider()
        Toggle("Automatically hide taskbar", isOn: $settings.preferences.autoHide)
        Button("Use classic taskbar behavior") { windows.resetWindowOrder(); settings.useTaskbarBehavior() }
    }

    private func adaptiveWidth(_ available: CGFloat, combined: Bool) -> CGFloat {
        let usesApplicationLabels = !windows.accessibilityGranted || combined
        let showsLabels = usesApplicationLabels ? preferences.showAppNames : preferences.showWindowTitles
        guard showsLabels else { return CGFloat(iconOnlyWidth) }
        if layout.itemSizing == .fixed { return CGFloat(layout.itemWidth) }
        let renderedCount = !windows.accessibilityGranted ? fallbackApplications.count
            : combined ? applicationKeys.count : visibleWindows.count
        let count = max(1, renderedCount)
        let width = (Double(available) - layout.itemSpacing * Double(count - 1)) / Double(count)
        return CGFloat(min(layout.maxItemWidth, max(layout.minItemWidth, width)))
    }

    @ViewBuilder private var pinButtons: some View {
        ForEach(preferences.pinnedApplicationPaths, id: \.self) { path in
            Button {
                NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init()) { _, error in
                    if let error { Task { @MainActor in settings.errorMessage = "Could not launch the pinned app: \(error.localizedDescription)" } }
                }
            } label: {
                Image(nsImage: AppIcons.icon(path: path)).resizable().frame(width: iconSize, height: iconSize)
                    .frame(width: layout.itemHeight, height: layout.itemHeight)
                    .contentShape(Rectangle())
                    .taskPaneDrag(enabled: options.allowPinDragging, payload: "taskpane-pin:\(path)")
            }.buttonStyle(.plain)
                .overlay(alignment: .topTrailing) { AppBadge(bundleIdentifier: Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier, enabled: options.showAppBadges) }
                .help(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                .accessibilityLabel("Launch \(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)")
                .contextMenu { Button("Unpin") { settings.togglePin(path: path) } }
                .dropDestination(for: String.self) { values, _ in
                    guard options.allowPinDragging, let value = values.first, value.hasPrefix("taskpane-pin:") else { return false }
                    let source = String(value.dropFirst("taskpane-pin:".count))
                    var pins = preferences.pinnedApplicationPaths
                    guard source != path, pins.contains(source), pins.contains(path) else { return false }
                    pins.removeAll { $0 == source }
                    guard let index = pins.firstIndex(of: path) else { return false }
                    pins.insert(source, at: index)
                    settings.preferences.pinnedApplicationPaths = pins
                    return true
                }
        }
    }

    @ViewBuilder private func windowButtons(width: CGFloat?, combined: Bool) -> some View {
        if !windows.accessibilityGranted {
            ForEach(fallbackApplications) { app in
                Button { windows.activateApp(pid: app.pid) } label: {
                    HStack(spacing: preferences.options.labelSpacing) {
                        Image(nsImage: AppIcons.icon(path: app.url?.path)).resizable().frame(width: iconSize, height: iconSize)
                        if !vertical && preferences.showAppNames { Text(app.name).lineLimit(1) }
                    }.frame(width: vertical ? nil : (preferences.showAppNames ? width : CGFloat(preferences.options.iconOnlyUsesItemHeight ? layout.itemHeight : preferences.options.iconOnlyWidth)), height: layout.itemHeight)
                        .background(Color.primary.opacity(layout.itemOpacity), in: RoundedRectangle(cornerRadius: layout.itemCornerRadius))
                        .contentShape(Rectangle())
                        .taskPaneDrag(enabled: options.allowWindowDragging, payload: app.bundleIdentifier ?? "app:\(app.name)")
                }.buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) { AppBadge(bundleIdentifier: app.bundleIdentifier, enabled: options.showAppBadges) }
                    .help("Activate \(app.name) · Enable Accessibility for individual windows")
                    .dropDestination(for: String.self) { keys, _ in
                        arrange(keys.first, before: app.bundleIdentifier ?? "app:\(app.name)")
                    }
            }
        } else if visibleWindows.isEmpty {
            Text(vertical ? "—" : "No windows on this display").font(.system(size: 11)).foregroundStyle(.secondary)
        } else if combined {
            let groups = Dictionary(grouping: visibleWindows, by: \.arrangementKey)
            ForEach(applicationKeys, id: \.self) { key in
                GroupedWindowButton(entries: groups[key] ?? [], windows: windows, settings: settings, vertical: vertical, width: width,
                                    interactionChanged: { open in
                    if open { presentedGroups.insert(key) } else { presentedGroups.remove(key) }
                })
                    .dropDestination(for: String.self) { keys, _ in arrange(keys.first, before: key) }
            }
        } else {
            ForEach(visibleWindows) { entry in
                WindowButton(entry: entry, windows: windows, settings: settings, vertical: vertical, width: width,
                             order: visibleWindows.map { String($0.id) }, showSettings: showSettings, move: moveWindow)
                    .modifier(WindowHoverPreview(entry: entry, windows: windows, settings: settings, displayBounds: displayBounds, arrowEdge: startArrowEdge,
                        interactionChanged: { open in
                            if open { previewGroups.insert(String(entry.id)) } else { previewGroups.remove(String(entry.id)) }
                        }))
                    .dropDestination(for: String.self) { keys, _ in
                        guard options.allowWindowDragging, let key = keys.first, key.hasPrefix("taskpane-window:") else { return false }
                        return moveWindow(String(key.dropFirst("taskpane-window:".count)), String(entry.id))
                    }
            }
        }
    }

    @discardableResult private func moveWindow(_ id: String, _ target: String?) -> Bool {
        let visible = visibleWindows
        guard options.allowWindowDragging, visible.contains(where: { String($0.id) == id }),
              target.map({ value in visible.contains(where: { String($0.id) == value }) }) ?? true else { return false }
        let entries = arrangedWindows
        var sources = [id]
        var destination = target
        // Adjacent mode keeps independent buttons but moves an app's block
        // across another app. Within one app, only the dragged window moves.
        if preferences.grouping == .adjacent,
           let selected = entries.first(where: { String($0.id) == id }),
           let target, let other = entries.first(where: { String($0.id) == target }),
           selected.arrangementKey != other.arrangementKey {
            sources = entries.filter { $0.arrangementKey == selected.arrangementKey }.map { String($0.id) }
            destination = entries.first(where: { $0.arrangementKey == other.arrangementKey }).map { String($0.id) } ?? target
        }
        let changed = windows.moveWindows(ids: sources, before: destination, currentOrder: entries.map { String($0.id) })
        if changed { settings.preferences.layout.autoArrange = false }
        return changed
    }

    private func arrange(_ key: String?, before target: String) -> Bool {
        let order = applicationKeys
        guard options.allowWindowDragging, let key, key != target, order.contains(key), order.contains(target) else { return false }
        // An earlier individual drag must not override this application move.
        windows.resetWindowOrder()
        settings.moveApplication(key, before: target, currentOrder: order, usingDisplayedOrder: true)
        return true
    }

    @ViewBuilder private var metricWidgets: some View {
        ForEach(visibleWidgets) { config in
            MetricChip(config: config, snapshot: metrics.snapshot,
                       history: config.kind == .cpu ? metrics.cpuHistory : config.kind == .memory ? metrics.memoryHistory : [], vertical: vertical)
        }
    }
}

struct WindowButton: View {
    let entry: WindowEntry
    @ObservedObject var windows: WindowService
    @ObservedObject var settings: SettingsStore
    let vertical: Bool
    var width: CGFloat? = nil
    let order: [String]
    let showSettings: () -> Void
    let move: (String, String?) -> Bool
    @ViewState private var hovered = false
    private var preferences: TaskPanePreferences { settings.preferences }
    private var layout: LayoutCustomization { preferences.layout }
    var body: some View {
        Button { windows.click(entry, secondClickMinimizes: preferences.secondClickMinimizes, hideApplication: preferences.options.focusedClickHidesApplication) } label: {
            HStack(spacing: preferences.options.labelSpacing) {
                Image(nsImage: AppIcons.icon(bundleIdentifier: entry.bundleIdentifier, pid: entry.pid)).resizable()
                    .frame(width: min(preferences.iconSize, layout.itemHeight - 2), height: min(preferences.iconSize, layout.itemHeight - 2))
                if preferences.options.showAllSpacesIndicator && entry.isOnAllSpaces {
                    Image(systemName: "pin.fill").font(.system(size: 9)).help("Shown on all desktops")
                }
                if !vertical && preferences.showWindowTitles {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, vertical ? min(2, preferences.options.itemHorizontalPadding) : preferences.options.itemHorizontalPadding)
            .frame(width: vertical ? nil : width, height: layout.itemHeight)
            .background(Color.primary.opacity(layout.itemOpacity + (hovered ? 0.07 : entry.isFocused ? 0.05 : 0)), in: RoundedRectangle(cornerRadius: layout.itemCornerRadius))
            .overlay(alignment: .bottom) {
                if layout.showActiveIndicator && entry.isFocused {
                    Capsule().fill(Color(taskPaneHex: preferences.accentHex)).frame(width: 20, height: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if layout.showMinimizedWindows && preferences.options.showMinimizedIndicator && entry.isMinimized {
                    Image(systemName: "minus").font(.system(size: 9, weight: .bold)).padding(3)
                }
            }
            .opacity(entry.isMinimized ? preferences.options.minimizedOpacity : entry.isHidden && preferences.options.dimHiddenWindows ? preferences.options.hiddenOpacity : 1)
            .contentShape(Rectangle())
            .taskPaneDrag(enabled: preferences.options.allowWindowDragging, payload: "taskpane-window:\(entry.id)")
        }
        .overlay(alignment: .topTrailing) { AppBadge(bundleIdentifier: entry.bundleIdentifier, enabled: preferences.options.showAppBadges) }
        .taskPaneMiddleClick(enabled: preferences.options.middleClickClosesWindow) { windows.close(entry) }
        .buttonStyle(.plain).help("\(entry.appName) · \(entry.title)")
        .accessibilityLabel("\(entry.appName): \(entry.title)")
        .accessibilityValue(entry.isMinimized ? "Minimized" : entry.isFocused ? "Focused" : "Open")
        .onHover { hovered = $0 }
        .contextMenu {
            WindowContextCommands(entry: entry, windows: windows, settings: settings)
            Divider()
            let index = order.firstIndex(of: String(entry.id)) ?? 0
            Button("Move earlier") { if index > 0 { _ = move(String(entry.id), order[index - 1]) } }
                .disabled(index == 0 || !preferences.options.allowWindowDragging)
            Button("Move later") { if index + 1 < order.count { _ = move(order[index + 1], String(entry.id)) } }
                .disabled(index + 1 >= order.count || !preferences.options.allowWindowDragging)
            Divider()
            Menu("TaskPane") {
                Button("Settings…", action: showSettings)
                Button("Refresh windows") { windows.refresh() }
            }
        }
    }
}

struct WindowContextCommands: View {
    let entry: WindowEntry
    @ObservedObject var windows: WindowService
    @ObservedObject var settings: SettingsStore
    private var application: RunningAppEntry? {
        guard windows.windows.contains(where: { $0.id == entry.id && $0.pid == entry.pid }) else { return nil }
        return windows.apps.first { $0.pid == entry.pid && $0.bundleIdentifier == entry.bundleIdentifier }
    }
    var body: some View {
        Text("Window · \(entry.appName)")
        Button("Activate window") { windows.activate(entry) }
        Button(entry.isMinimized ? "Restore window" : "Minimize window") {
            if entry.isMinimized { windows.activate(entry) } else { windows.minimize(entry) }
        }
        Button("Toggle full screen") { windows.toggleFullscreen(entry) }
        Button("Close window", role: .destructive) { windows.close(entry) }
        Divider()
        Text("Application")
        if let path = application?.url?.path {
            Button(settings.preferences.pinnedApplicationPaths.contains(path) ? "Remove from taskbar" : "Keep in taskbar") {
                settings.togglePin(path: path)
            }
        }
        if let application {
            Button("Hide \(entry.appName)") { windows.hideApplication(application) }
            Button("Quit \(entry.appName)") { windows.quitApplication(application) }
        }
        if let identifier = entry.bundleIdentifier {
            Button("Exclude \(entry.appName) from taskbar") { settings.excludeApplication(identifier) }
        }
    }
}

struct GroupedWindowButton: View {
    let entries: [WindowEntry]
    @ObservedObject var windows: WindowService
    @ObservedObject var settings: SettingsStore
    let vertical: Bool
    var width: CGFloat?
    let interactionChanged: (Bool) -> Void
    @ViewState private var presented = false
    private var preferences: TaskPanePreferences { settings.preferences }
    private var layout: LayoutCustomization { preferences.layout }
    var body: some View {
        Button {
            if entries.count == 1, let entry = entries.first { windows.click(entry, secondClickMinimizes: preferences.secondClickMinimizes, hideApplication: preferences.options.focusedClickHidesApplication) }
            else { presented.toggle() }
        } label: {
            if let first = entries.first {
                HStack(spacing: 6) {
                    Image(nsImage: AppIcons.icon(bundleIdentifier: first.bundleIdentifier, pid: first.pid)).resizable()
                        .frame(width: min(preferences.iconSize, layout.itemHeight - 2), height: min(preferences.iconSize, layout.itemHeight - 2))
                    if !vertical && preferences.showAppNames { Text(first.appName).lineLimit(1) }
                    if !vertical { Text("\(entries.count)").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary) }
                }.padding(.horizontal, preferences.options.itemHorizontalPadding).frame(width: vertical ? nil : (preferences.showAppNames ? width : CGFloat(preferences.options.iconOnlyUsesItemHeight ? layout.itemHeight : preferences.options.iconOnlyWidth)), height: layout.itemHeight)
                    .background(Color.primary.opacity(layout.itemOpacity), in: RoundedRectangle(cornerRadius: layout.itemCornerRadius))
                    .contentShape(Rectangle())
                    .taskPaneDrag(enabled: preferences.options.allowWindowDragging, payload: first.arrangementKey)
            }
        }.buttonStyle(.plain)
            .overlay(alignment: .topTrailing) { AppBadge(bundleIdentifier: entries.first?.bundleIdentifier, enabled: preferences.options.showAppBadges) }
            .help("\(entries.first?.appName ?? "App"): \(entries.count) windows")
            .popover(isPresented: $presented) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entries.first?.appName ?? "Windows").font(.headline)
                    ForEach(entries) { entry in
                        Button(entry.title.isEmpty ? "Untitled window" : entry.title) {
                            windows.click(entry, secondClickMinimizes: preferences.secondClickMinimizes, hideApplication: preferences.options.focusedClickHidesApplication); presented = false
                        }.buttonStyle(.plain).lineLimit(1).padding(.vertical, 5)
                            .contextMenu { WindowContextCommands(entry: entry, windows: windows, settings: settings) }
                    }
                }.padding(18).frame(minWidth: 240, maxWidth: 400)
            }
            .contextMenu {
                ForEach(entries) { entry in
                    Menu(entry.title.isEmpty ? "Untitled window" : entry.title) {
                        WindowContextCommands(entry: entry, windows: windows, settings: settings)
                    }
                }
            }
            .onChange(of: presented) { _, open in interactionChanged(open) }
            .onDisappear { interactionChanged(false) }
    }
}

struct MetricChip: View {
    let config: TaskPaneCore.WidgetConfiguration
    let snapshot: MetricSnapshot
    let history: [Double]
    var vertical = false
    private var value: String {
        if vertical && config.kind == .network {
            func short(_ bytes: Double?) -> String {
                guard let bytes, bytes.isFinite else { return "—" }
                if bytes >= 1_048_576 { return String(format: "%.1fM", bytes / 1_048_576) }
                if bytes >= 1024 { return String(format: "%.0fK", bytes / 1024) }
                return "\(Int(max(0, bytes)))B"
            }
            return "↓\(short(snapshot.networkDownBytesPerSecond))\n↑\(short(snapshot.networkUpBytesPerSecond))"
        }
        return MetricFormatting.text(config.kind, snapshot: snapshot, compact: config.style == .compact || vertical)
    }
    var body: some View {
        HStack(spacing: 5) {
            if config.showLabel && !vertical { Image(systemName: MetricFormatting.symbol(config.kind)).foregroundStyle(.secondary) }
            if config.style == .graph && !history.isEmpty && !vertical {
                Sparkline(values: history).frame(width: 42, height: 21)
            }
            Text(value)
                .font(.system(size: vertical ? 9 : 11, weight: .medium, design: .rounded))
                .monospacedDigit().lineLimit(vertical ? 2 : 1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, vertical ? 1 : 5)
        .help(config.kind.displayName + ": " + MetricFormatting.text(config.kind, snapshot: snapshot))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(config.kind.displayName)
        .accessibilityValue(MetricFormatting.text(config.kind, snapshot: snapshot))
    }
}
