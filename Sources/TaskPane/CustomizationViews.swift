import AppKit
import SwiftUI
import TaskPaneCore

struct LayoutSettingsView: View {
    @ObservedObject var settings: SettingsStore
    private var layout: LayoutCustomization { settings.preferences.layout }
    var body: some View {
        VStack(spacing: 20) {
            Surface(title: "Bar position & shape", subtitle: "Position is clamped to the display so the bar stays reachable.") {
                SettingRow(title: "Alignment") {
                    Picker("Alignment", selection: $settings.preferences.layout.alignment) {
                        ForEach(BarAlignment.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 180)
                }
                numeric("Bar length", value: $settings.preferences.layout.lengthPercent, range: 40...100, unit: "%")
                numeric("Distance from edge", value: $settings.preferences.layout.edgeOffset, range: 0...200)
                numeric("Position along edge", value: $settings.preferences.layout.alongEdgeOffset, range: -500...500)
                numeric("Bar corner radius", value: $settings.preferences.layout.barCornerRadius, range: 0...60)
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
                    numeric("Item width", value: $settings.preferences.layout.itemWidth, range: 48...420)
                } else {
                    numeric("Minimum width", value: Binding(get: { layout.minItemWidth }, set: { value in
                        var custom = layout; custom.minItemWidth = value; custom.maxItemWidth = max(value, custom.maxItemWidth); settings.preferences.layout = custom
                    }), range: 48...420)
                    numeric("Maximum width", value: Binding(get: { layout.maxItemWidth }, set: { value in
                        var custom = layout; custom.maxItemWidth = value; custom.minItemWidth = min(value, custom.minItemWidth); settings.preferences.layout = custom
                    }), range: 48...420)
                }
                numeric("Item height", value: $settings.preferences.layout.itemHeight, range: 24...100)
                numeric("Item spacing", value: $settings.preferences.layout.itemSpacing, range: 0...30)
                numeric("Item corner radius", value: $settings.preferences.layout.itemCornerRadius, range: 0...50)
                SettingRow(title: "Item background opacity") {
                    Slider(value: $settings.preferences.layout.itemOpacity, in: 0...1, step: 0.01).frame(width: 190)
                        .accessibilityLabel("Item background opacity")
                    Text("\(Int(layout.itemOpacity * 100))%").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                Text("Icons shrink to fit item height. The bar grows when needed to fit your items. Background transparency and icon/text sizes are in Appearance.")
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
        SettingRow(title: title) {
            Slider(value: value, in: range, step: 1).frame(width: 190).accessibilityLabel(title)
            TextField(title, value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder).frame(width: 55).multilineTextAlignment(.trailing)
                .onChange(of: value.wrappedValue) { _, number in
                    if !number.isFinite { value.wrappedValue = range.lowerBound }
                    else if !range.contains(number) { value.wrappedValue = min(range.upperBound, max(range.lowerBound, number)) }
                }
            Text(unit).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 18)
        }
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
