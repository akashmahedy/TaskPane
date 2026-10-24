import AppKit
import SwiftUI
import TaskPaneCore

struct LayoutSettingsView: View {
    @ObservedObject var settings: SettingsStore
    private var layout: LayoutCustomization { settings.preferences.layout }
    var body: some View {
        VStack(spacing: 20) {
            CurrentLayoutPreview(preferences: settings.preferences)
            Surface(title: "Overall scale", subtitle: "Resize the bar, buttons, icons and text together, then adjust each part below.") {
                CustomizationNumberRow(title: "Overall scale", value: Binding(get: {
                    min(250, max(50, settings.preferences.barHeight / 50 * 100))
                }, set: { percent in
                    settings.preferences = settings.preferences.usingOverallScale(percent)
                }), range: CustomizationLimits.overallScale, unit: "%")
                Text("100% uses a 50 pt bar, 40 pt items, 22 pt icons and 12 pt text. Values stay within each control’s range. Changing this scale replaces those size and padding values.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Surface(title: "Bar position & shape", subtitle: "Position is clamped to the display so the bar stays reachable.") {
                SettingRow(title: "Alignment") {
                    Picker("Alignment", selection: $settings.preferences.layout.alignment) {
                        ForEach(BarAlignment.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 180)
                }
                numeric("Bar length", value: $settings.preferences.layout.lengthPercent, range: CustomizationLimits.lengthPercent, unit: "%")
                numeric("Distance from edge", value: $settings.preferences.layout.edgeOffset, range: CustomizationLimits.edgeOffset)
                numeric("Position along edge", value: $settings.preferences.layout.alongEdgeOffset, range: CustomizationLimits.alongEdgeOffset)
                numeric("Bar corner radius", value: $settings.preferences.layout.barCornerRadius, range: CustomizationLimits.cornerRadius)
                Text("Choose the screen edge in Taskbar. Leading and trailing align along that edge; the position offset then moves the bar within the screen.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Surface(title: "Window item size", subtitle: "Fixed keeps every item the width you choose. Adaptive fits items within your limits.") {
                SettingRow(title: "Width behavior") {
                    Picker("Width behavior", selection: $settings.preferences.layout.itemSizing) {
                        ForEach(ItemSizing.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 180)
                }
                if layout.itemSizing == .fixed {
                    numeric("Item width", value: $settings.preferences.layout.itemWidth, range: CustomizationLimits.itemWidth)
                } else {
                    numeric("Minimum width", value: Binding(get: { layout.minItemWidth }, set: { value in
                        var custom = layout; custom.minItemWidth = value; custom.maxItemWidth = max(value, custom.maxItemWidth); settings.preferences.layout = custom
                    }), range: CustomizationLimits.itemWidth)
                    numeric("Maximum width", value: Binding(get: { layout.maxItemWidth }, set: { value in
                        var custom = layout; custom.maxItemWidth = value; custom.minItemWidth = min(value, custom.minItemWidth); settings.preferences.layout = custom
                    }), range: CustomizationLimits.itemWidth)
                }
                numeric("Item height", value: $settings.preferences.layout.itemHeight, range: CustomizationLimits.itemHeight)
                numeric("Item spacing", value: $settings.preferences.layout.itemSpacing, range: CustomizationLimits.spacing)
                numeric("Item corner radius", value: $settings.preferences.layout.itemCornerRadius, range: CustomizationLimits.cornerRadius)
                CustomizationNumberRow(title: "Item background opacity", value: Binding(get: { layout.itemOpacity * 100 }, set: { settings.preferences.layout.itemOpacity = $0 / 100 }), range: 0...100, unit: "%")
                Text("Effective bar thickness: \(Int(max(settings.preferences.barHeight, layout.itemHeight + ((settings.preferences.barEdge == .left || settings.preferences.barEdge == .right) ? settings.preferences.options.horizontalPadding : settings.preferences.options.verticalPadding) * 2))) pt. Effective icon size: \(Int(min(settings.preferences.iconSize, layout.itemHeight - 2))) pt. Background transparency and icon/text sizes are in Appearance; padding and behavior are in More controls.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Surface(title: "Quick density") {
                HStack(spacing: 12) {
                    densityButton("Tight", height: 28, spacing: 3)
                    densityButton("Comfortable", height: 36, spacing: 7)
                    densityButton("Spacious", height: 46, spacing: 12)
                }
                Toggle("Show section dividers", isOn: $settings.preferences.layout.showDividers).toggleStyle(.switch)
                Toggle("Show the focused-window indicator", isOn: $settings.preferences.layout.showActiveIndicator).toggleStyle(.switch)
            }
        }
    }

    private func numeric(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String = "pt") -> some View {
        CustomizationNumberRow(title: title, value: value, range: range, unit: unit)
    }

    private func densityButton(_ title: String, height: Double, spacing: Double) -> some View {
        Button(title) {
            var custom = layout; custom.itemHeight = height; custom.itemSpacing = spacing
            settings.preferences.layout = custom
        }.buttonStyle(.bordered)
    }
}

struct ArrangementSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var windows: WindowService
    private var layout: LayoutCustomization { settings.preferences.layout }
    private func key(_ app: RunningAppEntry) -> String { app.bundleIdentifier ?? "app:\(app.name)" }
    private var applications: [RunningAppEntry] {
        var seen = Set<String>()
        return windows.apps.filter { seen.insert(key($0)).inserted }.sorted {
            let lhs = layout.applicationOrder.firstIndex(of: key($0)) ?? Int.max
            let rhs = layout.applicationOrder.firstIndex(of: key($1)) ?? Int.max
            return lhs == rhs ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : lhs < rhs
        }
    }
    var body: some View {
        VStack(spacing: 20) {
            Surface(title: "Section order", subtitle: "Move the launcher, pins, windows, widgets and settings to the positions you prefer.") {
                ForEach(Array(layout.sectionOrder.enumerated()), id: \.element) { index, section in
                    HStack {
                        Text("\(index + 1)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 22)
                        Text(section.displayName).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Button { settings.moveSection(section, direction: -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(index == 0).accessibilityLabel("Move \(section.displayName) earlier")
                        Button { settings.moveSection(section, direction: 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(index == layout.sectionOrder.count - 1).accessibilityLabel("Move \(section.displayName) later")
                    }.padding(.vertical, 4)
                }
            }
            Surface(title: "Window & application order", subtitle: "Drag individual window buttons on the taskbar. Adjacent mode keeps each app's windows together.") {
                Toggle("Use automatic ordering", isOn: $settings.preferences.layout.autoArrange).toggleStyle(.switch)
                if layout.autoArrange {
                    SettingRow(title: "Sort by") {
                        Picker("Sort by", selection: $settings.preferences.layout.sortOrder) {
                            ForEach(WindowSortOrder.allCases) { Text($0.displayName).tag($0) }
                        }.labelsHidden().frame(width: 180)
                    }
                } else {
                    Text("Drag a window button onto another to change its position for this session. The controls below set the saved order of application blocks.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    ForEach(Array(applications.enumerated()), id: \.element.id) { index, app in
                        HStack(spacing: 10) {
                            Image(nsImage: AppIcons.icon(path: app.url?.path)).resizable().frame(width: 23, height: 23)
                            Text(app.name).font(.system(size: 12)); Spacer()
                            Button {
                                windows.resetWindowOrder()
                                settings.moveApplication(key(app), direction: -1, currentOrder: applications.map(key))
                            } label: { Image(systemName: "chevron.up") }
                                .disabled(index == 0).accessibilityLabel("Move \(app.name) earlier")
                            Button {
                                windows.resetWindowOrder()
                                settings.moveApplication(key(app), direction: 1, currentOrder: applications.map(key))
                            } label: { Image(systemName: "chevron.down") }
                                .disabled(index == applications.count - 1).accessibilityLabel("Move \(app.name) later")
                        }.padding(.vertical, 3)
                    }
                    if !windows.manualWindowOrder.isEmpty {
                        Button("Reset individual window order") { windows.resetWindowOrder() }
                            .buttonStyle(.bordered)
                    }
                }
                Divider()
                Text("Application and section order are included in preferences export/import. Individual window order lasts for this session. Pinned applications have their own order in Taskbar.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
