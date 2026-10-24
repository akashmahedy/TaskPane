import AppKit
import SwiftUI
import TaskPaneCore

/// Numeric entry and slider share one range. Text is committed on Return or blur,
/// so typing a multi-digit value never saves an invalid intermediate preference.
struct CustomizationNumberRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String = "pt"
    var step: Double = 1
    @ViewState private var draft = ""
    @FocusState private var editing: Bool

    private var slider: Binding<Double> {
        Binding(get: { value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound }, set: { proposed in
            guard proposed.isFinite else { return }
            value = min(range.upperBound, max(range.lowerBound, (proposed / step).rounded() * step))
        })
    }
    private func sync() { draft = value.formatted(.number.precision(.fractionLength(0...2))) }
    private func commit() {
        let parser = NumberFormatter()
        parser.numberStyle = .decimal
        if let number = parser.number(from: draft)?.doubleValue, number.isFinite {
            slider.wrappedValue = number
        }
        sync()
    }
    var body: some View {
        SettingRow(title: title) {
            Slider(value: slider, in: range).frame(width: 175).accessibilityLabel(title)
            TextField(title, text: $draft).textFieldStyle(.roundedBorder).frame(width: 65)
                .multilineTextAlignment(.trailing).focused($editing)
                .onSubmit(commit).accessibilityLabel("\(title) value")
            Text(unit).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 25)
        }
        .onAppear(perform: sync)
        .onChange(of: value) { _, _ in if !editing { sync() } }
        .onChange(of: editing) { _, focused in if !focused { commit() } }
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SettingsStore
    private var options: TaskbarAdvancedOptions { settings.preferences.options }
    @ViewBuilder private func number(_ title: String, _ key: WritableKeyPath<TaskbarAdvancedOptions, Double>, _ range: ClosedRange<Double>, unit: String = "pt", step: Double = 1) -> some View {
        if unit == "0–1" {
            CustomizationNumberRow(title: title, value: Binding(get: { options[keyPath: key] * 100 }, set: { settings.preferences.options[keyPath: key] = $0 / 100 }), range: 0...100, unit: "%")
        } else {
            CustomizationNumberRow(title: title, value: Binding(get: { options[keyPath: key] }, set: { settings.preferences.options[keyPath: key] = $0 }), range: range, unit: unit, step: step)
        }
    }
    private func toggle(_ title: String, _ key: WritableKeyPath<TaskbarAdvancedOptions, Bool>) -> some View {
        Toggle(title, isOn: Binding(get: { options[keyPath: key] }, set: { settings.preferences.options[keyPath: key] = $0 }))
    }
    var body: some View {
        VStack(spacing: 20) {
            CurrentLayoutPreview(preferences: settings.preferences)
            spacing
            interactions
            windowStates
            hiding
            previews
            startMenu
            displays
            DockSettingsView()
        }.toggleStyle(.switch)
    }
    private var spacing: some View {
        Surface(title: "Padding, borders & shadow", subtitle: "Adjust the space around the bar and inside every window button.") {
            OptionalBackgroundColorRow(title: "Bar background color", value: Binding(get: { options.barBackgroundHex }, set: { settings.preferences.options.barBackgroundHex = $0 }))
            OptionalBackgroundColorRow(title: "Button background color", value: Binding(get: { options.itemBackgroundHex }, set: { settings.preferences.options.itemBackgroundHex = $0 }))
            number("Horizontal bar padding", \.horizontalPadding, CustomizationLimits.padding)
            number("Vertical bar padding", \.verticalPadding, CustomizationLimits.padding)
            number("Section spacing", \.sectionSpacing, CustomizationLimits.spacing)
            number("Icon and title gap", \.labelSpacing, CustomizationLimits.spacing)
            number("Button horizontal padding", \.itemHorizontalPadding, CustomizationLimits.padding)
            toggle("Make icon-only buttons square", \.iconOnlyUsesItemHeight)
            if !options.iconOnlyUsesItemHeight { number("Icon-only button width", \.iconOnlyWidth, CustomizationLimits.itemWidth) }
            number("Border width", \.barBorderWidth, CustomizationLimits.borderWidth, step: 0.5)
            number("Border opacity", \.barBorderOpacity, CustomizationLimits.opacity, unit: "0–1", step: 0.01)
            toggle("Show bar shadow", \.barShadow)
        }
    }
    private var interactions: some View {
        Surface(title: "Window & pin interaction") {
            toggle("Show standard macOS tabs as separate tasks", \.showStandardTabs)
            Text("AppKit tabs have separate activate and close actions. Minimize and full screen affect their shared window. Browser page tabs remain inside their browser.").font(.system(size: 11)).foregroundStyle(.secondary)
            toggle("Allow dragging window buttons", \.allowWindowDragging)
            toggle("Allow dragging pinned apps", \.allowPinDragging)
            toggle("Middle-click closes the window", \.middleClickClosesWindow)
            toggle("Click the focused window to hide its app", \.focusedClickHidesApplication)
            Text("Hide takes priority over second-click minimize when both are enabled. Middle-click uses the window's normal close command, so unsaved documents can still ask to save.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            toggle("Show application badges", \.showAppBadges)
        }
    }
    private var windowStates: some View {
        Surface(title: "Hidden & minimized windows") {
            number("Minimized window opacity", \.minimizedOpacity, CustomizationLimits.opacity, unit: "0–1", step: 0.01)
            toggle("Show minimized window marker", \.showMinimizedIndicator)
            toggle("Dim windows of hidden apps", \.dimHiddenWindows)
            if options.dimHiddenWindows { number("Hidden app opacity", \.hiddenOpacity, CustomizationLimits.opacity, unit: "0–1", step: 0.01) }
        }
    }
    private var hiding: some View {
        Surface(title: "Auto-hide & reveal", subtitle: "Enable auto-hide in Taskbar to use these timings.") {
            number("Delay before hiding", \.autoHideDelay, CustomizationLimits.delay, unit: "s", step: 0.05)
            number("Delay before revealing", \.revealDelay, CustomizationLimits.delay, unit: "s", step: 0.05)
            number("Visible activation strip", \.revealStrip, CustomizationLimits.revealStrip)
            number("Animation duration", \.animationDuration, CustomizationLimits.animationDuration, unit: "s", step: 0.01)
            toggle("Hide taskbar in full screen", \.hideInFullscreen)
            Text("Reduce motion disables animation while keeping the same hide and reveal delays.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    private var previews: some View {
        Surface(title: "Hover window previews", subtitle: "Thumbnails need optional Screen Recording permission. The taskbar works without it.") {
            toggle("Show window thumbnails on hover", \.hoverPreviewsEnabled)
            PreviewPermissionView()
            number("Hover delay", \.previewDelay, CustomizationLimits.delay, unit: "s", step: 0.05)
            number("Preview width", \.previewWidth, CustomizationLimits.previewWidth)
            number("Preview height", \.previewHeight, CustomizationLimits.previewHeight)
            number("Preview title size", \.previewTitleFontSize, CustomizationLimits.fontSize)
        }
    }
    private var startMenu: some View {
        Surface(title: "Start menu", subtitle: "The menu fits within the display when your requested size is larger.") {
            number("Menu width", \.startMenuWidth, CustomizationLimits.startMenuWidth)
            number("Menu height", \.startMenuHeight, CustomizationLimits.startMenuHeight)
            number("App name text size", \.startMenuFontSize, CustomizationLimits.fontSize)
            number("App icon size", \.startMenuIconSize, CustomizationLimits.iconSize)
        }
    }
    private var displays: some View {
        Surface(title: "Displays & overlapping windows") {
            toggle("Track native macOS Spaces when supported", \.nativeSpaceTracking)
            toggle("Mark windows shown on all desktops", \.showAllSpacesIndicator)
            Text("Native Space tracking uses a checked macOS compatibility reader. If unavailable, TaskPane falls back to window visibility. Enable off-screen windows in Taskbar to show windows from every Space.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            toggle("Resize windows that overlap the taskbar", \.resizeOverlappingWindows)
            Text("Uses Accessibility to fit eligible normal windows above or beside the bar. Disable this to leave other windows where you place them.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            toggle("Use full screen bounds for bar placement", \.useScreenFrame)
            Text("Full bounds allow placement in the Dock's reserved area. Available bounds respect the Dock and menu bar.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Text("Taskbar visibility on connected displays").font(.system(size: 12, weight: .medium))
            ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                if let identifier = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
                    Toggle("\(screen.localizedName)\(index == 0 ? " · main display" : "")", isOn: Binding(get: {
                        !options.hiddenDisplayIDs.contains(identifier)
                    }, set: { visible in
                        var updated = options.hiddenDisplayIDs.filter { $0 != identifier }
                        if !visible { updated.append(identifier) }
                        settings.preferences.options.hiddenDisplayIDs = updated
                    }))
                }
            }
            Text("Enable “Show TaskPane on every display” in Taskbar to display bars beyond the main screen.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

/// Scaled sample content uses current preferences without inspecting real windows.
struct CurrentLayoutPreview: View {
    let preferences: TaskPanePreferences
    private var layout: LayoutCustomization { preferences.layout }
    private var options: TaskbarAdvancedOptions { preferences.options }
    private var vertical: Bool { preferences.barEdge == .left || preferences.barEdge == .right }
    private var barAlignment: Alignment {
        switch preferences.barEdge {
        case .top: return .top
        case .left: return .leading
        case .right: return .trailing
        case .bottom: return .bottom
        }
    }

    /// Resolve arithmetic before constructing views. Keeping numeric overloads out
    /// of the view builder also supports the older Swift compiler used by CI.
    private struct Dimensions {
        let scale: CGFloat
        let width: CGFloat
        let height: CGFloat
        let itemWidth: CGFloat?
        let itemHeight: CGFloat
        let itemSpacing: CGFloat
        let labelSpacing: CGFloat
        let itemPadding: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let iconSize: CGFloat
        let fontSize: CGFloat
        let itemRadius: CGFloat
        let barRadius: CGFloat
        let borderWidth: CGFloat

        init(preferences: TaskPanePreferences, availableWidth: CGFloat) {
            let layout = preferences.layout
            let options = preferences.options
            let vertical = preferences.barEdge == .left || preferences.barEdge == .right
            let padding = vertical ? options.horizontalPadding : options.verticalPadding
            let thickness = CGFloat(max(preferences.barHeight, layout.itemHeight + padding * 2))
            scale = min(CGFloat(0.65), availableWidth / 1000)
            let requestedLength = availableWidth * CGFloat(layout.lengthPercent) / 100
            width = max(CGFloat(35), min(availableWidth, vertical ? thickness * scale : requestedLength))
            height = min(CGFloat(100), max(CGFloat(20), vertical ? CGFloat(100) : thickness * scale))

            if vertical {
                itemWidth = nil
            } else if !preferences.showWindowTitles {
                let requested = options.iconOnlyUsesItemHeight ? layout.itemHeight : options.iconOnlyWidth
                itemWidth = CGFloat(requested) * scale
            } else if layout.itemSizing == .fixed {
                itemWidth = CGFloat(layout.itemWidth) * scale
            } else {
                let paddingWidth = CGFloat(options.horizontalPadding) * 2 * scale
                let spacingWidth = CGFloat(layout.itemSpacing) * 2 * scale
                let availablePerItem = max(CGFloat(0), width - paddingWidth - spacingWidth) / 3
                itemWidth = min(CGFloat(layout.maxItemWidth) * scale,
                                max(CGFloat(layout.minItemWidth) * scale, availablePerItem))
            }
            itemHeight = max(CGFloat(10), min(CGFloat(80), CGFloat(layout.itemHeight) * scale))
            itemSpacing = min(CGFloat(15), CGFloat(layout.itemSpacing) * scale)
            labelSpacing = min(CGFloat(12), CGFloat(options.labelSpacing) * scale)
            itemPadding = min(CGFloat(15), CGFloat(options.itemHorizontalPadding) * scale)
            horizontalPadding = min(CGFloat(30), CGFloat(options.horizontalPadding) * scale)
            verticalPadding = min(CGFloat(20), CGFloat(options.verticalPadding) * scale)
            let fittedIcon = CGFloat(min(preferences.iconSize, layout.itemHeight - 2)) * scale
            iconSize = max(CGFloat(6), min(CGFloat(32), fittedIcon))
            fontSize = max(CGFloat(6), min(CGFloat(22), CGFloat(preferences.fontSize) * scale))
            itemRadius = CGFloat(layout.itemCornerRadius) * scale
            barRadius = CGFloat(layout.barCornerRadius) * scale
            borderWidth = CGFloat(options.barBorderWidth) * scale
        }
    }

    var body: some View {
        Surface(title: "Your current layout", subtitle: "Scaled illustration. Changes appear on your taskbar as you adjust them.") {
            GeometryReader { geometry in
                desktop(availableWidth: geometry.size.width)
            }.frame(height: 115)
            Text(sizeDescription).font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Content grows the bar to fit. Icons and text fit inside each button. Display bounds can reduce the requested bar or menu size.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var sizeDescription: String {
        "Bar \(Int(preferences.barHeight)) pt minimum · Items \(Int(layout.itemHeight)) pt high · Icons \(Int(preferences.iconSize)) pt requested · Text \(Int(preferences.fontSize)) pt"
    }

    private func desktop(availableWidth: CGFloat) -> some View {
        let dimensions = Dimensions(preferences: preferences, availableWidth: availableWidth)
        return ZStack(alignment: barAlignment) {
            RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.07))
            sampleBar(dimensions)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current \(preferences.barEdge.displayName) taskbar preview, \(Int(layout.lengthPercent)) percent length")
    }

    private func sampleBar(_ dimensions: Dimensions) -> some View {
        sampleItems(dimensions)
            .padding(.horizontal, dimensions.horizontalPadding)
            .padding(.vertical, dimensions.verticalPadding)
            .frame(width: dimensions.width, height: dimensions.height)
            .background(Color(nsColor: .controlBackgroundColor).opacity(preferences.barOpacity))
            .clipShape(RoundedRectangle(cornerRadius: dimensions.barRadius))
            .overlay(barBorder(dimensions))
            .shadow(color: .black.opacity(options.barShadow ? 0.15 : 0), radius: 3, y: 1)
    }

    private func barBorder(_ dimensions: Dimensions) -> some View {
        RoundedRectangle(cornerRadius: dimensions.barRadius)
            .stroke(Color.primary.opacity(options.barBorderOpacity), lineWidth: dimensions.borderWidth)
    }

    private func sampleItems(_ dimensions: Dimensions) -> some View {
        let axis: AnyLayout = vertical
            ? AnyLayout(VStackLayout(spacing: dimensions.itemSpacing))
            : AnyLayout(HStackLayout(spacing: dimensions.itemSpacing))
        return axis {
            if preferences.showLauncher {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(.tint)
            }
            ForEach(0..<3) { index in sampleItem(index, dimensions: dimensions) }
        }
    }

    private func sampleItem(_ index: Int, dimensions: Dimensions) -> some View {
        sampleItemLabel(index, dimensions: dimensions)
            .padding(.horizontal, dimensions.itemPadding)
            .frame(width: dimensions.itemWidth)
            .frame(height: dimensions.itemHeight)
            .background(Color.primary.opacity(layout.itemOpacity), in: RoundedRectangle(cornerRadius: dimensions.itemRadius))
            .opacity(index == 2 ? options.minimizedOpacity : 1)
    }

    private func sampleItemLabel(_ index: Int, dimensions: Dimensions) -> some View {
        HStack(spacing: dimensions.labelSpacing) {
            Image(systemName: ["folder.fill", "safari", "doc.text.fill"][index])
                .font(.system(size: dimensions.iconSize))
            if preferences.showWindowTitles && !vertical {
                Text(["Files", "Research", "Notes"][index])
                    .font(.system(size: dimensions.fontSize)).lineLimit(1)
            }
        }
    }
}

struct OptionalBackgroundColorRow: View {
    let title: String
    @Binding var value: String?
    var body: some View {
        SettingRow(title: title) {
            ColorPicker(title, selection: Binding(get: { value.map { Color(taskPaneHex: $0) } ?? Color(nsColor: .windowBackgroundColor) }, set: { color in
                guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                value = String(format: "%02X%02X%02X", Int((min(1, max(0, rgb.redComponent)) * 255).rounded()), Int((min(1, max(0, rgb.greenComponent)) * 255).rounded()), Int((min(1, max(0, rgb.blueComponent)) * 255).rounded()))
            }), supportsOpacity: false).labelsHidden()
            Button("Use system color") { value = nil }.disabled(value == nil)
        }
    }
}
