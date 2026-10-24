import AppKit
import SwiftUI
import TaskPaneCore

private enum SettingsPage: String, CaseIterable, Identifiable {
    case overview, taskbar, layout, arrangement, appearance, advanced, widgets, presets, backup, about
    var id: String { rawValue }
    var title: String { self == .layout ? "Layout & items" : self == .arrangement ? "Arrange" : self == .advanced ? "More controls" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .taskbar: return "rectangle.bottomthird.inset.filled"
        case .layout: return "slider.horizontal.3"
        case .arrangement: return "arrow.up.arrow.down"
        case .appearance: return "paintpalette"
        case .advanced: return "gearshape.2"
        case .widgets: return "waveform.path.ecg"
        case .presets: return "square.stack.3d.up"
        case .backup: return "externaldrive.badge.timemachine"
        case .about: return "info.circle"
        }
    }
    var subtitle: String {
        switch self {
        case .overview: return "A calmer workspace, with everything in reach."
        case .taskbar: return "Choose how your windows and applications behave."
        case .layout: return "Fine-tune item sizes, spacing, transparency and bar position."
        case .arrangement: return "Choose automatic sorting or put every section in your own order."
        case .appearance: return "Make every edge feel like your own."
        case .advanced: return "Fine-tune interactions, previews, padding, Start and display behavior."
        case .widgets: return "Your system, at a glance. Put each widget where it belongs."
        case .presets: return "Start with a thoughtful setup, then make it yours."
        case .backup: return "Keep your setup safe and take it to another Mac."
        case .about: return "A free, open-source workspace companion for macOS."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var metrics: MetricsService
    @ObservedObject var windows: WindowService
    @ObservedObject var launcher: LauncherService
    @ViewState private var page: SettingsPage = .overview
    @ViewState private var excludedApp = ""
    @ViewState private var windowSearch = ""
    private var accent: Color { Color(taskPaneHex: settings.preferences.accentHex) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(page.title).font(.system(size: 28, weight: .bold))
                            Text(page.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("PRIVATE ALPHA").font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.1).padding(.horizontal, 10).padding(.vertical, 6)
                            .foregroundStyle(accent).background(accent.opacity(0.11), in: Capsule())
                    }.padding(.bottom, 3)
                    if let notice = settings.notice {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(notice).font(.system(size: 12))
                            Spacer()
                            Button { settings.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss message")
                        }.padding(12).background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    }
                    content
                    Text("TaskPane 0.1.0  ·  Created by akashmahedy")
                        .font(.system(size: 10)).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.top, 8)
                }.padding(30).frame(maxWidth: 960, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(accent)
        .alert("TaskPane", isPresented: Binding(get: { settings.errorMessage != nil }, set: { if !$0 { settings.errorMessage = nil } })) {
            Button("OK") { settings.errorMessage = nil }
        } message: { Text(settings.errorMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.split.3x1.fill").font(.system(size: 28)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TaskPane").font(.system(size: 21, weight: .bold))
                    Text("Your workspace, your way").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 16).padding(.top, 24)
            ScrollView {
                VStack(spacing: 5) {
                ForEach(SettingsPage.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).font(.system(size: 15)).frame(width: 20)
                            Text(item.title).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                            Spacer()
                        }
                        .foregroundStyle(page == item ? accent : Color.primary.opacity(0.75))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(page == item ? accent.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
                }
                }.padding(.horizontal, 12)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 7) {
                Label("Local by design", systemImage: "lock.shield").font(.system(size: 11, weight: .medium))
                Text("Free. Open source. Yours.").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12)).padding(12)
        }.frame(width: 220).background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .overview: overview
        case .taskbar: taskbar
        case .layout: LayoutSettingsView(settings: settings)
        case .arrangement: ArrangementSettingsView(settings: settings, windows: windows)
        case .appearance: appearance
        case .advanced: AdvancedSettingsView(settings: settings)
        case .widgets: widgets
        case .presets: presets
        case .backup: backup
        case .about: about
        }
    }

    private var overview: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Everything in reach.").font(.system(size: 27, weight: .bold))
                    Text("Bring windows, favorite apps and live system insights together. Keep the parts you need, exactly where you need them.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Customize your bar") { page = .taskbar }.buttonStyle(.borderedProminent)
                        Button("Explore presets") { page = .presets }.buttonStyle(.bordered)
                    }.padding(.top, 4)
                }
                Spacer(minLength: 5)
                Image(systemName: "rectangle.split.3x1.fill").font(.system(size: 70, weight: .light)).foregroundStyle(accent.opacity(0.85)).accessibilityHidden(true)
            }.padding(25).background(accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 18))

            HStack(spacing: 14) {
                metricCard("CPU", value: metrics.snapshot.cpuPercent.map { String(format: "%.0f%%", $0) } ?? "Sampling…", detail: "Processor usage", symbol: "cpu", history: metrics.cpuHistory)
                metricCard("Memory", value: String(format: "%.0f%%", metrics.snapshot.memoryPercent), detail: MetricFormatting.bytes(metrics.snapshot.memoryUsedBytes) + " of " + MetricFormatting.bytes(metrics.snapshot.memoryTotalBytes), symbol: "memorychip", history: metrics.memoryHistory)
                metricCard("Network", value: MetricFormatting.speed(metrics.snapshot.networkDownBytesPerSecond), detail: "Upload " + MetricFormatting.speed(metrics.snapshot.networkUpBytesPerSecond), symbol: "arrow.up.arrow.down", history: [])
            }

            Surface(title: "Your setup", subtitle: "Changes are saved automatically on this Mac.") {
                SettingRow(title: "App mode", subtitle: "Keep a taskbar, menu bar widgets, or both.") {
                    Picker("App mode", selection: $settings.preferences.appMode) {
                        ForEach(AppMode.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 200)
                }
                Divider()
                SettingRow(title: "Window control", subtitle: windows.accessibilityGranted ? "Accessibility access is available." : "Allow Accessibility to minimize and close individual windows. App switching works without it.") {
                    if windows.accessibilityGranted { Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 12)) }
                    else { Button("Enable window control") { windows.requestAccessibility() } }
                }
                Divider()
                HStack {
                    Label("\(windows.windows.count) windows", systemImage: "macwindow")
                    Spacer()
                    Label("\(launcher.applications.count) applications", systemImage: "square.grid.2x2")
                    Spacer()
                    Button("Refresh") { windows.refresh() }
                }.font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if let message = windows.lastActionMessage { Text(message).font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            Surface(title: "Open windows", subtitle: "Switch directly, or use the window controls after granting Accessibility.") {
                TextField("Search windows or applications", text: $windowSearch).textFieldStyle(.roundedBorder)
                let entries = windows.windows.filter { windowSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(windowSearch) || $0.appName.localizedCaseInsensitiveContains(windowSearch) }
                if entries.isEmpty { Text("No matching windows.").font(.system(size: 12)).foregroundStyle(.secondary) }
                ForEach(Array(entries.prefix(8))) { entry in
                    HStack(spacing: 10) {
                        Image(nsImage: AppIcons.icon(bundleIdentifier: entry.bundleIdentifier, pid: entry.pid)).resizable().frame(width: 23, height: 23)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title.isEmpty ? entry.appName : entry.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Text(entry.appName).font(.system(size: 10)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Button("Activate") { windows.activate(entry) }.help("Activate \(entry.appName): \(entry.title)")
                        Button { windows.minimize(entry) } label: { Image(systemName: "minus") }
                            .disabled(!windows.accessibilityGranted).accessibilityLabel("Minimize \(entry.appName): \(entry.title)")
                        Button { windows.close(entry) } label: { Image(systemName: "xmark") }
                            .disabled(!windows.accessibilityGranted).accessibilityLabel("Close \(entry.appName): \(entry.title)")
                        Menu {
                            WindowContextCommands(entry: entry, windows: windows, settings: settings)
                        } label: { Image(systemName: "ellipsis") }
                            .accessibilityLabel("More controls for \(entry.appName): \(entry.title)")
                    }.padding(.vertical, 4)
                }
                if entries.count > 8 { Text("Showing 8 of \(entries.count) windows. Search to narrow the list.").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Surface(title: "Private alpha", subtitle: "A working foundation, with clear boundaries.") {
                Text("Available now: window and app switching, pins, launcher, display placement, live CPU / memory / network / battery, presets, and portable preference backups.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("More controls adds optional window thumbnails, drag locks, auto-hide timing, window state styling and menu sizing. Advanced Spaces handling, GPU / temperature sensors, snapping and saved layouts remain planned.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricCard(_ title: String, value: String, detail: String, symbol: String, history: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: symbol).foregroundStyle(accent); Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary); Spacer() }
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Sparkline(values: history, color: accent).frame(height: 24)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var taskbar: some View {
        VStack(spacing: 20) {
            Surface(title: "Classic taskbar behavior", subtitle: "Keep every window directly clickable, put the same app's windows together, and restore minimized windows from the bar.") {
                Button("Use classic taskbar behavior") { windows.resetWindowOrder(); settings.useTaskbarBehavior() }
                    .buttonStyle(.borderedProminent)
                Text("Keeps your appearance, widgets, pins and exclusions. Window titles and cross-display windows are enabled; individual window order stays stable for this session.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Surface(title: "Placement & behavior") {
                SettingRow(title: "App mode") { enumPicker($settings.preferences.appMode, title: "App mode") }
                Divider()
                SettingRow(title: "Screen edge") { enumPicker($settings.preferences.barEdge, title: "Screen edge") }
                Divider()
                SettingRow(title: "Window grouping") { enumPicker($settings.preferences.grouping, title: "Window grouping") }
                Divider()
                Toggle("Show TaskPane on every display", isOn: $settings.preferences.showOnAllDisplays)
                Toggle("Show only this display’s windows", isOn: $settings.preferences.currentDisplayOnly)
                Toggle("Automatically hide the taskbar", isOn: $settings.preferences.autoHide)
                Toggle("Click the focused window again to minimize it", isOn: $settings.preferences.secondClickMinimizes)
                Toggle("Show application launcher", isOn: $settings.preferences.showLauncher)
                Toggle("Show window titles", isOn: $settings.preferences.showWindowTitles)
                Toggle("Show application names in grouped mode", isOn: $settings.preferences.showAppNames)
                Divider()
                Toggle("Include minimized windows", isOn: $settings.preferences.layout.showMinimizedWindows)
                Toggle("Include off-screen windows", isOn: $settings.preferences.layout.showOffscreenWindows)
                Toggle("Include dialog windows", isOn: $settings.preferences.layout.showDialogs)
                Text("Only actual Accessibility windows are listed. Helper panels and duplicate Core Graphics records are excluded. Without permission, TaskPane shows one button per running app.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.toggleStyle(.switch)
            Surface(title: "Pinned applications", subtitle: "Pins stay available even when the application is not running.") {
                if settings.preferences.pinnedApplicationPaths.isEmpty { Text("No pins yet. Add your everyday apps here or pin them in the launcher.").font(.system(size: 12)).foregroundStyle(.secondary) }
                ForEach(Array(settings.preferences.pinnedApplicationPaths.enumerated()), id: \.element) { index, path in
                    HStack(spacing: 10) {
                        Image(nsImage: AppIcons.icon(path: path)).resizable().frame(width: 24, height: 24)
                        Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent).font(.system(size: 12))
                        Spacer()
                        Button { movePin(index, direction: -1) } label: { Image(systemName: "chevron.up") }.disabled(index == 0).accessibilityLabel("Move pin earlier")
                        Button { movePin(index, direction: 1) } label: { Image(systemName: "chevron.down") }.disabled(index == settings.preferences.pinnedApplicationPaths.count - 1).accessibilityLabel("Move pin later")
                        Button("Remove") { settings.togglePin(path: path) }
                    }
                }
                Button("Add applications…", systemImage: "plus") { settings.addPinnedApplication() }
            }
            Surface(title: "Excluded applications", subtitle: "Hide an app from TaskPane using its bundle identifier.") {
                HStack {
                    TextField("For example: com.apple.finder", text: $excludedApp)
                    Button("Add") {
                        let value = excludedApp.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty, !settings.preferences.excludedBundleIdentifiers.contains(value) else { return }
                        settings.excludeApplication(value); excludedApp = ""
                    }.disabled(excludedApp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(settings.preferences.excludedBundleIdentifiers, id: \.self) { identifier in
                    HStack { Text(identifier).font(.system(size: 12, design: .monospaced)); Spacer(); Button("Remove") { settings.preferences.excludedBundleIdentifiers.removeAll { $0 == identifier } } }
                }
            }
            Text("TaskPane leaves your macOS Dock settings unchanged. The bar sits inside the display’s available area.")
                .font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appearance: some View {
        VStack(spacing: 20) {
            CurrentLayoutPreview(preferences: settings.preferences)
            Surface(title: "A look that fits your workspace") {
                SettingRow(title: "Theme") { enumPicker($settings.preferences.theme, title: "Theme") }
                Divider()
                SettingRow(title: "Accent color") {
                    HStack(spacing: 10) {
                        ForEach(["5B8CFF", "18A999", "A078E8", "E98A3A", "DD6479", "778899"], id: \.self) { hex in
                            Button { settings.preferences.accentHex = hex } label: {
                                Circle().fill(Color(taskPaneHex: hex)).frame(width: 23, height: 23)
                                    .overlay { if settings.preferences.accentHex == hex { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
                            }.buttonStyle(.plain).accessibilityLabel("Accent \(hex)")
                        }
                    }
                }
                SettingRow(title: "Custom accent", subtitle: "Six-digit RGB hex value") {
                    ColorPicker("Custom accent", selection: Binding(get: { accent }, set: { color in
                        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                        settings.preferences.accentHex = String(format: "%02X%02X%02X", Int((min(1, max(0, rgb.redComponent)) * 255).rounded()), Int((min(1, max(0, rgb.greenComponent)) * 255).rounded()), Int((min(1, max(0, rgb.blueComponent)) * 255).rounded()))
                    }), supportsOpacity: false).labelsHidden()
                    Text("#" + settings.preferences.accentHex).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                Divider()
                sliderRow("Minimum bar thickness", value: $settings.preferences.barHeight, range: CustomizationLimits.barHeight, suffix: "pt")
                sliderRow("Icon size", value: $settings.preferences.iconSize, range: CustomizationLimits.iconSize, suffix: "pt")
                sliderRow("Text size", value: $settings.preferences.fontSize, range: CustomizationLimits.fontSize, suffix: "pt")
                CustomizationNumberRow(title: "Background opacity", value: Binding(get: { settings.preferences.barOpacity * 100 }, set: { settings.preferences.barOpacity = $0 / 100 }), range: 0...100, unit: "%")
                Divider()
                Toggle("Reduce motion", isOn: $settings.preferences.reduceMotion).toggleStyle(.switch)
            }
            Surface(title: "Designed for clarity") {
                Text("Native typography, light and dark surfaces, keyboard-accessible controls, and readable system insights. Window titles can be hidden for a quieter bar.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private var widgets: some View {
        VStack(spacing: 18) {
            Surface(title: "One engine. Two places.", subtitle: "Showing a widget in both bars shares the same sample; it does not duplicate monitoring.") {
                SettingRow(title: "Refresh interval", subtitle: "Slower updates reduce background work.") {
                    Picker("Refresh interval", selection: $settings.preferences.refreshInterval) {
                        ForEach([1.0, 2, 3, 5, 10, 30, 60], id: \.self) { Text("\(Int($0)) seconds").tag($0) }
                    }.labelsHidden().frame(width: 150)
                }
                Toggle("Show taskbar clock", isOn: $settings.preferences.showClock).toggleStyle(.switch)
            }
            ForEach($settings.preferences.widgets) { $widget in
                Surface {
                    HStack(spacing: 12) {
                        Image(systemName: MetricFormatting.symbol(widget.kind)).font(.system(size: 20)).foregroundStyle(accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(widget.kind.displayName).font(.system(size: 14, weight: .semibold))
                            Text(MetricFormatting.text(widget.kind, snapshot: metrics.snapshot)).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        enumPicker($widget.placement, title: "\(widget.kind.displayName) placement")
                    }
                    Divider()
                    HStack {
                        Text("Style").font(.system(size: 12))
                        Picker("Widget style", selection: $widget.style) {
                            ForEach(WidgetStyle.allCases.filter { $0 != .graph || widget.kind == .cpu || widget.kind == .memory }) { Text($0.displayName).tag($0) }
                        }.labelsHidden().frame(width: 165)
                        Spacer()
                        Toggle("Show icon", isOn: $widget.showLabel).toggleStyle(.switch).font(.system(size: 12))
                    }
                    if widget.kind == .network { Text("Rates cover the routed primary interface. No external IP lookup or connectivity request is made.").font(.system(size: 10)).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var presets: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
            ForEach(BuiltInPreset.allCases) { preset in
                Surface {
                    PresetPreview(preset: preset)
                    Text(preset.displayName).font(.system(size: 16, weight: .semibold))
                    Text(preset.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).frame(minHeight: 35, alignment: .topLeading)
                    Button(settings.activePreset == preset.rawValue ? "Applied" : "Apply preset") { settings.apply(preset) }
                        .buttonStyle(.bordered).tint(settings.activePreset == preset.rawValue ? .green : accent)
                }
            }
        }
    }

    private var backup: some View {
        VStack(spacing: 20) {
            Surface(title: "Your preferences, portable", subtitle: "A versioned JSON backup keeps your customization together.") {
                Label("Appearance, item sizes, position and arrangement", systemImage: "checkmark.circle").font(.system(size: 12))
                Label("Widget placements, styles and refresh interval", systemImage: "checkmark.circle").font(.system(size: 12))
                Label("Pinned apps and excluded applications", systemImage: "checkmark.circle").font(.system(size: 12))
                Divider()
                HStack(spacing: 12) {
                    Button("Export preferences…", systemImage: "square.and.arrow.up") { settings.exportPreferences() }.buttonStyle(.borderedProminent)
                    Button("Import preferences…", systemImage: "square.and.arrow.down") { settings.importPreferences() }.buttonStyle(.bordered)
                }
            }
            Surface(title: "Safe to bring back") {
                Text("Imports are validated before changing your setup. Invalid or unsupported files leave your current preferences untouched. You will see a confirmation before a valid import replaces your setup.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text("Backups contain your app paths and preferences. They do not contain passwords, screen captures or permission grants.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Surface(title: "Saved on this Mac") {
                Text(settings.storagePath).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                Button("Show settings folder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.storagePath) }
            }
        }
    }

    private var about: some View {
        VStack(spacing: 20) {
            Surface {
                HStack(alignment: .top, spacing: 22) {
                    Image(systemName: "rectangle.split.3x1.fill").font(.system(size: 62)).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TaskPane").font(.system(size: 30, weight: .bold))
                        Text("0.1.0 · Private alpha").foregroundStyle(.secondary)
                        Text("Created by akashmahedy").font(.system(size: 16, weight: .semibold))
                        Text("Free and open source · GPL-3.0-or-later").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("A native macOS taskbar and menu bar companion. Built around personal customization, useful presets and preferences you can carry with you.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Surface(title: "Credits & principles") {
                Text("Product direction and creator credit: akashmahedy.")
                Text("Engineering assistance: OpenAI Codex.")
                Text("Feature research references: Taskbar, uBar, Sidebar and Stats. This alpha uses original code and Apple frameworks; it does not bundle their binaries or source.")
                Text("No account, ads, analytics, cloud monitoring or paid unlock. Preferences stay on your Mac unless you export them.")
            }.font(.system(size: 12)).foregroundStyle(.secondary)
            Surface(title: "Alpha boundaries") {
                Text("Not notarized. Accessibility is optional and must be granted by you for window control. Some apps expose incomplete or nonstandard window lists; TaskPane refuses actions when the exact selected window cannot be verified.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private func enumPicker<T: CaseIterable & Hashable & Identifiable & DisplayNamed>(_ selection: Binding<T>, title: String) -> some View where T.AllCases: RandomAccessCollection {
        Picker(title, selection: selection) { ForEach(Array(T.allCases)) { Text($0.displayName).tag($0) } }.labelsHidden().frame(width: 165)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        CustomizationNumberRow(title: title, value: value, range: range, unit: suffix)
    }

    private func movePin(_ index: Int, direction: Int) {
        let target = index + direction
        guard settings.preferences.pinnedApplicationPaths.indices.contains(target) else { return }
        settings.preferences.pinnedApplicationPaths.swapAt(index, target)
    }
}

private protocol DisplayNamed { var displayName: String { get } }
extension AppMode: DisplayNamed {}
extension BarEdge: DisplayNamed {}
extension GroupingMode: DisplayNamed {}
extension ThemeMode: DisplayNamed {}
extension WidgetPlacement: DisplayNamed {}
extension WidgetStyle: DisplayNamed {}

struct LauncherView: View {
    @ObservedObject var launcher: LauncherService
    @ObservedObject var settings: SettingsStore
    @ViewState private var query = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search applications", text: $query).textFieldStyle(.plain).font(.system(size: 18))
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("Clear search") }
            }.padding(22)
            Divider()
            List {
                ForEach(launcher.applications.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { app in
                    HStack(spacing: 12) {
                        Image(nsImage: AppIcons.icon(path: app.url.path)).resizable().frame(width: 32, height: 32)
                        Button { launcher.launch(app) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.system(size: 13, weight: .medium))
                                Text(app.url.deletingLastPathComponent().path).font(.system(size: 10)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button { settings.togglePin(path: app.url.path) } label: {
                            Image(systemName: settings.preferences.pinnedApplicationPaths.contains(app.url.path) ? "pin.fill" : "pin")
                        }.buttonStyle(.plain).help("Pin or unpin \(app.name)").accessibilityLabel("Pin or unpin \(app.name)")
                    }.padding(.vertical, 6)
                }
            }.listStyle(.inset)
            HStack {
                Text(launcher.lastLaunchMessage ?? "\(launcher.applications.count) applications · Created by akashmahedy").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { launcher.refresh() }
            }.padding(14)
        }.tint(Color(taskPaneHex: settings.preferences.accentHex))
    }
}
