import SwiftUI
import TaskPaneCore

/// An illustrated desktop, not a second set of window controls. All labels and
/// readings are fixed examples; this view never inspects the user's workspace.
struct PresetPreview: View {
    let preset: BuiltInPreset
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var hovering = false

    private var preferences: TaskPanePreferences { preset.preferences }
    private var accent: Color { Color(taskPaneHex: preferences.accentHex) }
    private var dark: Bool {
        preferences.theme == .dark || (preferences.theme == .system && colorScheme == .dark)
    }
    private var ink: Color { dark ? .white : Color(red: 0.16, green: 0.20, blue: 0.27) }
    private var panel: Color { dark ? Color(red: 0.14, green: 0.17, blue: 0.22) : .white }
    private var edgeInset: CGFloat { CGFloat(preferences.layout.edgeOffset) * 0.5 }
    private var barRadius: CGFloat { CGFloat(preferences.layout.barCornerRadius) * 0.5 }
    private let cpuHistory: [Double] = [20, 24, 18, 32, 28, 44, 29, 24, 30, 24]
    private let memoryHistory: [Double] = [48, 49, 49, 53, 54, 53, 58, 60, 59, 62]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [accent.opacity(dark ? 0.20 : 0.12), dark ? Color(red: 0.10, green: 0.13, blue: 0.19) : Color(red: 0.91, green: 0.94, blue: 0.97)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Circle().fill(accent.opacity(dark ? 0.10 : 0.06))
                    .frame(width: 150, height: 150).offset(x: geometry.size.width - 100, y: 18)
                desktopWindows(width: geometry.size.width)
                menuBar(width: geometry.size.width)
                taskbar(width: geometry.size.width, height: geometry.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(ink.opacity(0.09), lineWidth: 1))
        }
        .frame(minWidth: 240, maxWidth: .infinity)
        .frame(height: 138)
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.displayName) preset preview. \(summary)")
        .accessibilityHint("Illustrated example. Use Apply preset below to enable this layout.")
    }

    @ViewBuilder private func desktopWindows(width: CGFloat) -> some View {
        switch preset {
        case .balanced:
            sampleWindow("Files", symbol: "folder.fill", tint: .cyan, width: width * 0.42, height: 61)
                .offset(x: width * 0.49, y: 33)
            sampleWindow("Safari", symbol: "safari", tint: accent, width: width * 0.52, height: 69)
                .offset(x: 17, y: 29)
        case .windows:
            sampleWindow("Files · Projects", symbol: "folder.fill", tint: .cyan, width: width * 0.48, height: 65)
                .offset(x: width * 0.43, y: 31)
            sampleWindow("Safari · Research", symbol: "safari", tint: accent, width: width * 0.58, height: 72)
                .offset(x: 13, y: 25)
        case .compact:
            sampleWindow("Notes", symbol: "note.text", tint: .orange, width: width * 0.40, height: 61)
                .offset(x: width * 0.53, y: 37)
            sampleWindow("Safari", symbol: "safari", tint: accent, width: width * 0.55, height: 68)
                .offset(x: 19, y: 28)
        case .monitoring:
            sampleWindow("Your workspace", symbol: "rectangle.3.group", tint: accent, width: width * 0.72, height: 76)
                .offset(x: width * 0.14, y: 39)
        case .focus:
            sampleWindow("Notes · A little room to focus", symbol: "note.text", tint: accent, width: width * 0.70, height: 68)
                .offset(x: width * 0.15, y: 30)
        }
    }

    private func sampleWindow(_ title: String, symbol: String, tint: Color, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach([Color.red, .orange, .green].indices, id: \.self) { index in
                    Circle().fill([Color.red, .orange, .green][index].opacity(0.65)).frame(width: 4, height: 4)
                }
                Spacer(minLength: 2)
                Text(title).font(.system(size: 6, weight: .medium)).lineLimit(1).foregroundStyle(ink.opacity(0.72))
                Spacer(minLength: 2)
            }.padding(.horizontal, 7).frame(height: 14).background(ink.opacity(0.035))
            HStack(alignment: .top, spacing: 9) {
                VStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(tint)
                    RoundedRectangle(cornerRadius: 1).fill(tint.opacity(0.20)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 1).fill(ink.opacity(0.07)).frame(height: 3)
                }.frame(width: 21).padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.14)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 1).fill(ink.opacity(0.10)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 1).fill(ink.opacity(0.06)).frame(width: max(15, width * 0.37), height: 3)
                }
            }.padding(9).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: width, height: height)
        .background(panel, in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ink.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(dark ? 0.20 : 0.08), radius: 5, y: 3)
        .accessibilityHidden(true)
    }

    private func menuBar(width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "command").font(.system(size: 7, weight: .bold))
            if preset != .monitoring {
                Text("Safari").font(.system(size: 7, weight: .semibold))
                if width > 280 { Text("File   Edit   View").font(.system(size: 6)) }
            }
            Spacer(minLength: 3)
            if preset == .monitoring {
                menuMetric("CPU 24%")
                menuMetric("RAM 62%")
                Text("↓ 2.4 MB/s").font(.system(size: 6, weight: .medium, design: .monospaced))
                if width > 285 { Image(systemName: "battery.75percent").font(.system(size: 8)) }
            } else if preset == .compact {
                Text("24%  62%  ↓ 2.4M").font(.system(size: 6, weight: .medium, design: .monospaced))
                Image(systemName: "battery.75percent").font(.system(size: 8))
            } else {
                Image(systemName: "wifi").font(.system(size: 7))
                Image(systemName: "battery.75percent").font(.system(size: 8))
            }
            Text("9:41").font(.system(size: 6, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(ink.opacity(0.85)).padding(.horizontal, 9)
        .frame(height: preset == .monitoring ? 24 : 19)
        .background(panel.opacity(dark ? 0.85 : 0.70))
        .overlay(alignment: .bottom) {
            if preset == .monitoring { Rectangle().fill(accent.opacity(0.55)).frame(height: 1) }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func taskbar(width: CGFloat, height: CGFloat) -> some View {
        switch preset {
        case .balanced:
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 10)).foregroundStyle(accent)
                windowButton("Safari", symbol: "safari", active: true)
                windowButton("Files", symbol: "folder.fill")
                miniMetric("CPU 24%", values: cpuHistory)
                miniMetric("RAM 62%", values: memoryHistory)
                if preferences.showClock { clock }
            }
            .padding(.horizontal, 8).frame(width: barWidth(in: width), height: 29)
            .background(panel.opacity(preferences.barOpacity), in: RoundedRectangle(cornerRadius: barRadius))
            .overlay(RoundedRectangle(cornerRadius: barRadius).stroke(ink.opacity(0.07), lineWidth: 0.5))
            .offset(x: barOrigin(in: width), y: height - 29 - edgeInset)
        case .windows:
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 11)).foregroundStyle(accent).frame(width: 19)
                windowButton(width > 285 ? "Safari · Research" : "Safari", symbol: "safari", active: true)
                windowButton("Files · Projects", symbol: "folder.fill")
                clock.padding(.horizontal, 5)
            }
            .padding(.horizontal, 5).frame(width: barWidth(in: width), height: 28).background(panel.opacity(preferences.barOpacity))
            .overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.09)).frame(height: 0.5) }
            .offset(x: barOrigin(in: width), y: height - 28 - edgeInset)
        case .compact:
            HStack(spacing: 9) {
                appIcon("safari", tint: accent)
                appIcon("folder.fill", tint: .cyan)
                appIcon("note.text", tint: .orange)
                appIcon("bubble.left.and.bubble.right.fill", tint: .green)
            }
            .padding(.horizontal, 10).frame(width: barWidth(in: width), height: 29)
            .background(panel.opacity(preferences.barOpacity), in: RoundedRectangle(cornerRadius: barRadius))
            .overlay(RoundedRectangle(cornerRadius: barRadius).stroke(ink.opacity(0.10), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
            .offset(x: barOrigin(in: width), y: height - 29 - edgeInset)
        case .monitoring:
            EmptyView()
        case .focus:
            VStack(spacing: 7) {
                if !hovering {
                    Text("Hover to reveal").font(.system(size: 7, weight: .medium))
                        .foregroundStyle(ink.opacity(0.65))
                }
                if hovering {
                    HStack(spacing: 10) {
                        appIcon("safari", tint: accent)
                        appIcon("folder.fill", tint: .cyan)
                        appIcon("note.text", tint: .orange)
                    }
                    .padding(.horizontal, 10).frame(width: barWidth(in: width), height: 27)
                    .background(panel.opacity(preferences.barOpacity), in: RoundedRectangle(cornerRadius: barRadius))
                    .overlay(RoundedRectangle(cornerRadius: barRadius).stroke(ink.opacity(0.08), lineWidth: 0.5))
                } else {
                    Capsule().fill(accent.opacity(0.85)).frame(width: 46, height: 4)
                }
            }
            .frame(width: barWidth(in: width), height: 35, alignment: .bottom)
            .offset(x: barOrigin(in: width), y: height - 35 - edgeInset)
        }
    }

    private func barWidth(in width: CGFloat) -> CGFloat {
        width * CGFloat(preferences.layout.lengthPercent / 100)
    }

    private func barOrigin(in width: CGFloat) -> CGFloat {
        switch preferences.layout.alignment {
        case .leading: return 0
        case .center: return (width - barWidth(in: width)) / 2
        case .trailing: return width - barWidth(in: width)
        }
    }

    private func windowButton(_ title: String, symbol: String, active: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 8)).foregroundStyle(accent)
            Text(title).font(.system(size: 6.5, weight: active ? .semibold : .regular)).lineLimit(1)
        }
        .foregroundStyle(ink.opacity(0.88)).padding(.horizontal, 5)
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        .background(active ? accent.opacity(0.12) : ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .bottom) {
            if active { Capsule().fill(accent).frame(height: 1.5).padding(.horizontal, 5) }
        }
    }

    private func appIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(tint)
            .frame(width: 20, height: 20).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private func miniMetric(_ label: String, values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 5.5, weight: .medium, design: .monospaced)).foregroundStyle(ink.opacity(0.8))
            Sparkline(values: values, color: accent).frame(height: 7)
        }.frame(width: 30)
    }

    private func menuMetric(_ label: String) -> some View {
        Text(label).font(.system(size: 6, weight: .medium, design: .monospaced))
    }

    private var clock: some View {
        Text("9:41").font(.system(size: 6.5, weight: .semibold, design: .monospaced)).foregroundStyle(ink.opacity(0.8))
    }

    private var summary: String {
        switch preset {
        case .balanced: return "Separate window titles and CPU and memory graphs along the bottom."
        case .windows: return "A full-width bottom taskbar with separate titled windows and a clock."
        case .compact: return "A short centered dock of application icons, with monitoring in the top menu bar."
        case .monitoring: return "CPU, memory and network readings in the top menu bar. No taskbar."
        case .focus: return "A narrow bottom activation strip. Hover the preview to reveal a compact taskbar."
        }
    }
}
