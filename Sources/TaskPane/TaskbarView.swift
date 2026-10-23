import AppKit
import SwiftUI
import TaskPaneCore

extension WindowEntry {
    var arrangementKey: String { bundleIdentifier ?? "app:\(appName)" }
}

struct TaskbarView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var metrics: MetricsService
    @ObservedObject var windows: WindowService
    let displayBounds: CGRect
    let vertical: Bool
    let showSettings: () -> Void
    let showLauncher: () -> Void
    private var preferences: TaskPanePreferences { settings.preferences }
    private var layout: LayoutCustomization { preferences.layout }
    private var iconSize: Double { min(preferences.iconSize, layout.itemHeight - 8) }

    private var visibleWindows: [WindowEntry] {
        windows.windows.filter { entry in
            !preferences.excludedBundleIdentifiers.contains(entry.bundleIdentifier ?? "") &&
            (!preferences.currentDisplayOnly || displayBounds.contains(CGPoint(x: entry.bounds.midX, y: entry.bounds.midY))) &&
            (layout.showMinimizedWindows || !entry.isMinimized) &&
            (layout.showDialogs || !entry.isDialog) &&
            (layout.showOffscreenWindows || entry.isOnScreen || entry.isMinimized)
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
            let comparison = lhs.appName.localizedStandardCompare(rhs.appName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return lhs.id < rhs.id
        }
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
    private var groupedWindows: Bool {
        preferences.grouping == .always || (preferences.grouping == .automatic && visibleWindows.count > 7)
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
                VStack(spacing: layout.itemSpacing) {
                    ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                        if layout.showDividers && index > 0 { Divider() }
                        sectionContent(section)
                    }
                }.padding(6)
            } else {
                HStack(spacing: layout.itemSpacing + 4) {
                    ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                        if layout.showDividers && index > 0 { Divider().padding(.vertical, 7) }
                        sectionContent(section)
                    }
                }.padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .font(.system(size: min(preferences.fontSize, layout.itemHeight - 8)))
        .background(Color(nsColor: .windowBackgroundColor).opacity(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : preferences.barOpacity))
        .clipShape(RoundedRectangle(cornerRadius: layout.barCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: layout.barCornerRadius).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .tint(Color(taskPaneHex: preferences.accentHex))
        .accessibilityElement(children: .contain).accessibilityLabel("TaskPane taskbar")
    }

    @ViewBuilder private func sectionContent(_ section: BarSection) -> some View {
        switch section {
        case .launcher:
            Button(action: showLauncher) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: max(12, iconSize - 2), weight: .semibold))
                    .foregroundStyle(Color(taskPaneHex: preferences.accentHex)).frame(width: layout.itemHeight, height: layout.itemHeight)
            }.buttonStyle(.plain).help("Open application launcher").accessibilityLabel("Open application launcher")
        case .pins:
            if vertical { VStack(spacing: layout.itemSpacing) { pinButtons } }
            else { HStack(spacing: layout.itemSpacing) { pinButtons } }
        case .windows:
            GeometryReader { area in
                ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
                    if vertical { VStack(spacing: layout.itemSpacing) { windowButtons(width: nil) } }
                    else { HStack(spacing: layout.itemSpacing) { windowButtons(width: adaptiveWidth(area.size.width)) }.frame(minHeight: area.size.height) }
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

    private func adaptiveWidth(_ available: CGFloat) -> CGFloat {
        let usesApplicationLabels = !windows.accessibilityGranted || groupedWindows
        let showsLabels = usesApplicationLabels ? preferences.showAppNames : preferences.showWindowTitles
        guard showsLabels else { return CGFloat(layout.itemHeight) }
        if layout.itemSizing == .fixed { return CGFloat(layout.itemWidth) }
        let renderedCount = !windows.accessibilityGranted ? fallbackApplications.count
            : groupedWindows ? applicationKeys.count : visibleWindows.count
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
            }.buttonStyle(.plain).help(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                .accessibilityLabel("Launch \(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)")
                .contextMenu { Button("Unpin") { settings.togglePin(path: path) } }
        }
    }

    @ViewBuilder private func windowButtons(width: CGFloat?) -> some View {
        if !windows.accessibilityGranted {
            ForEach(fallbackApplications) { app in
                Button { windows.activateApp(pid: app.pid) } label: {
                    HStack(spacing: 7) {
                        Image(nsImage: AppIcons.icon(path: app.url?.path)).resizable().frame(width: iconSize, height: iconSize)
                        if !vertical && preferences.showAppNames { Text(app.name).lineLimit(1) }
                    }.frame(width: vertical ? nil : (preferences.showAppNames ? width : CGFloat(layout.itemHeight)), height: layout.itemHeight)
                        .background(Color.primary.opacity(layout.itemOpacity), in: RoundedRectangle(cornerRadius: layout.itemCornerRadius))
                }.buttonStyle(.plain).help("Activate \(app.name) · Enable Accessibility for individual windows")
                    .draggable(app.bundleIdentifier ?? "app:\(app.name)")
                    .dropDestination(for: String.self) { keys, _ in
                        arrange(keys.first, before: app.bundleIdentifier ?? "app:\(app.name)")
                    }
            }
        } else if visibleWindows.isEmpty {
            Text(vertical ? "—" : "No windows on this display").font(.system(size: 11)).foregroundStyle(.secondary)
        } else if groupedWindows {
            let groups = Dictionary(grouping: visibleWindows, by: \.arrangementKey)
            ForEach(applicationKeys, id: \.self) { key in
                GroupedWindowButton(entries: groups[key] ?? [], windows: windows, preferences: preferences, vertical: vertical, width: width)
                    .draggable(key)
                    .dropDestination(for: String.self) { keys, _ in arrange(keys.first, before: key) }
            }
        } else {
            ForEach(visibleWindows) { entry in
                WindowButton(entry: entry, windows: windows, preferences: preferences, vertical: vertical, width: width)
                    .draggable(entry.arrangementKey)
                    .dropDestination(for: String.self) { keys, _ in arrange(keys.first, before: entry.arrangementKey) }
            }
        }
    }

    private func arrange(_ key: String?, before target: String) -> Bool {
        guard let key, key != target, applicationKeys.contains(key) else { return false }
        settings.moveApplication(key, before: target, currentOrder: applicationKeys)
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
    let preferences: TaskPanePreferences
    let vertical: Bool
    var width: CGFloat? = nil
    private var layout: LayoutCustomization { preferences.layout }
    var body: some View {
        Button { windows.click(entry, secondClickMinimizes: preferences.secondClickMinimizes) } label: {
            HStack(spacing: 7) {
                Image(nsImage: AppIcons.icon(bundleIdentifier: entry.bundleIdentifier, pid: entry.pid)).resizable()
                    .frame(width: min(preferences.iconSize, layout.itemHeight - 8), height: min(preferences.iconSize, layout.itemHeight - 8))
                if !vertical && preferences.showWindowTitles {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, vertical ? 2 : 7)
            .frame(width: vertical ? nil : width, height: layout.itemHeight)
            .background(Color.primary.opacity(layout.itemOpacity), in: RoundedRectangle(cornerRadius: layout.itemCornerRadius))
            .overlay(alignment: .bottom) {
                if layout.showActiveIndicator && entry.isFocused {
                    Capsule().fill(Color(taskPaneHex: preferences.accentHex)).frame(width: 20, height: 3)
                }
            }
        }
        .buttonStyle(.plain).help("\(entry.appName) · \(entry.title)")
        .accessibilityLabel("\(entry.appName): \(entry.title)")
        .contextMenu {
            Button("Activate window") { windows.activate(entry) }
            Button("Minimize window") { windows.minimize(entry) }
            Divider()
            Button("Close window", role: .destructive) { windows.close(entry) }
        }
    }
}

struct GroupedWindowButton: View {
    let entries: [WindowEntry]
    @ObservedObject var windows: WindowService
    let preferences: TaskPanePreferences
    let vertical: Bool
    var width: CGFloat?
    @ViewState private var presented = false
    private var layout: LayoutCustomization { preferences.layout }
    var body: some View {
        Button {
            if entries.count == 1, let entry = entries.first { windows.click(entry, secondClickMinimizes: preferences.secondClickMinimizes) }
            else { presented.toggle() }
        } label: {
            if let first = entries.first {
                HStack(spacing: 6) {
                    Image(nsImage: AppIcons.icon(bundleIdentifier: first.bundleIdentifier, pid: first.pid)).resizable()
                        .frame(width: min(preferences.iconSize, layout.itemHeight - 8), height: min(preferences.iconSize, layout.itemHeight - 8))
                    if !vertical && preferences.showAppNames { Text(first.appName).lineLimit(1) }
                    if !vertical { Text("\(entries.count)").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary) }
                }.padding(.horizontal, 5).frame(width: vertical ? nil : (preferences.showAppNames ? width : CGFloat(layout.itemHeight)), height: layout.itemHeight)
                    .background(Color.primary.opacity(layout.itemOpacity), in: RoundedRectangle(cornerRadius: layout.itemCornerRadius))
            }
        }.buttonStyle(.plain).help("\(entries.first?.appName ?? "App"): \(entries.count) windows")
            .popover(isPresented: $presented) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entries.first?.appName ?? "Windows").font(.headline)
                    ForEach(entries) { entry in
                        Button(entry.title.isEmpty ? "Untitled window" : entry.title) { windows.activate(entry); presented = false }
                            .buttonStyle(.plain).lineLimit(1).padding(.vertical, 5)
                    }
                }.padding(18).frame(minWidth: 240, maxWidth: 400)
            }
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
