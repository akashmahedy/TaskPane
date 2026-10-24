import AppKit
import SwiftUI
import TaskPaneCore

/// Adds an optional, delayed preview without replacing the button's primary
/// click, context menu, or native drag source. A short grace period lets the
/// pointer cross from the button into the preview controls.
struct WindowHoverPreview: ViewModifier {
    let entry: WindowEntry
    @ObservedObject var windows: WindowService
    @ObservedObject var settings: SettingsStore
    var displayBounds: CGRect = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1000, height: 800)
    var arrowEdge: Edge = .bottom
    var interactionChanged: (Bool) -> Void = { _ in }
    @ViewState private var presented = false
    @ViewState private var sourceHovered = false
    @ViewState private var previewHovered = false
    @ViewState private var showTask: Task<Void, Never>?
    @ViewState private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { entered in
                sourceHovered = entered
                if entered { scheduleShow() }
                else { showTask?.cancel(); scheduleDismiss() }
            }
            .popover(isPresented: $presented, arrowEdge: arrowEdge) {
                WindowPreviewView(entry: entry, windows: windows, settings: settings, displayBounds: displayBounds, dismiss: dismiss)
                    .onHover { entered in
                        previewHovered = entered
                        if entered { dismissTask?.cancel() } else { scheduleDismiss() }
                    }
            }
            .accessibilityAction(named: Text("Preview window")) {
                guard settings.preferences.options.hoverPreviewsEnabled else { return }
                showTask?.cancel(); dismissTask?.cancel(); presented = true
            }
            .onChange(of: presented) { _, open in
                if !open { previewHovered = false }
                interactionChanged(open)
            }
            .onChange(of: settings.preferences.options.hoverPreviewsEnabled) { _, enabled in
                if !enabled { dismiss(); WindowPreviewService.shared.clear() }
            }
            .onDisappear {
                showTask?.cancel(); dismissTask?.cancel(); interactionChanged(false)
            }
    }

    private func scheduleShow() {
        dismissTask?.cancel()
        showTask?.cancel()
        guard settings.preferences.options.hoverPreviewsEnabled, !presented else { return }
        let delay = min(CustomizationLimits.delay.upperBound, max(CustomizationLimits.delay.lowerBound,
                                                               settings.preferences.options.previewDelay))
        showTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard !Task.isCancelled, sourceHovered, settings.preferences.options.hoverPreviewsEnabled,
                  windows.windows.contains(where: { $0.id == entry.id && $0.pid == entry.pid }) else { return }
            presented = true
        }
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            guard !Task.isCancelled, !sourceHovered, !previewHovered else { return }
            presented = false
        }
    }

    private func dismiss() {
        showTask?.cancel(); dismissTask?.cancel(); presented = false
    }
}

struct WindowPreviewView: View {
    let entry: WindowEntry
    @ObservedObject var windows: WindowService
    @ObservedObject var settings: SettingsStore
    var displayBounds: CGRect = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1000, height: 800)
    var dismiss: () -> Void = {}
    @ObservedObject private var previews = WindowPreviewService.shared
    @ViewState private var result: WindowPreviewService.Preview?

    private var options: TaskbarAdvancedOptions { settings.preferences.options }
    private var liveEntry: WindowEntry? {
        windows.windows.first { $0.id == entry.id && $0.pid == entry.pid }
    }
    private var width: Double { min(options.previewWidth, max(160, displayBounds.width - 64)) }
    private var height: Double { min(options.previewHeight, max(100, displayBounds.height - max(150, options.previewTitleFontSize * 2 + 100))) }
    private var requestIdentity: String {
        let current = liveEntry ?? entry
        return "\(liveEntry == nil ? "gone" : "live")-\(current.id)-\(current.pid)-\(current.captureWindowID ?? 0)-\(current.title)-\(current.bounds)-\(current.isMinimized)-\(width)-\(height)-\(previews.permissionGranted)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(nsImage: AppIcons.icon(bundleIdentifier: entry.bundleIdentifier, pid: entry.pid))
                    .resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveEntry?.title ?? entry.title).font(.system(size: options.previewTitleFontSize, weight: .medium))
                        .lineLimit(2)
                    Text(entry.appName).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button(action: dismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Dismiss window preview")
            }
            previewContent
                .frame(width: width, height: height)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 8) {
                Button { if let liveEntry { windows.activate(liveEntry) }; dismiss() } label: {
                    controlLabel("Activate", symbol: "arrow.up.forward.app")
                }.help("Activate window")
                Button {
                    if let liveEntry {
                        if liveEntry.isMinimized { windows.activate(liveEntry) } else { windows.minimize(liveEntry) }
                    }
                    dismiss()
                } label: {
                    controlLabel(liveEntry?.isMinimized == true ? "Restore" : "Minimize",
                                 symbol: liveEntry?.isMinimized == true ? "arrow.up.left.and.arrow.down.right" : "minus")
                }.help(liveEntry?.isMinimized == true ? "Restore window" : "Minimize window")
                Spacer(minLength: 0)
                Button(role: .destructive) { if let liveEntry { windows.close(liveEntry) }; dismiss() } label: {
                    controlLabel("Close window", symbol: "xmark")
                }.help("Close window")
            }.buttonStyle(.bordered).controlSize(.small).disabled(liveEntry == nil)
        }
        .padding(12).frame(width: width + 24)
        .onExitCommand(perform: dismiss)
        .task(id: requestIdentity) {
            result = nil
            guard options.hoverPreviewsEnabled, let current = liveEntry else {
                result = .unavailable("This window is no longer available.")
                return
            }
            let requestedID = current.captureWindowID
            let requestedBounds = current.bounds
            let requestedTitle = current.title
            let captured = await previews.preview(for: current, width: width, height: height) {
                guard settings.preferences.options.hoverPreviewsEnabled,
                      let live = windows.windows.first(where: { $0.id == current.id && $0.pid == current.pid }) else { return false }
                return live.captureWindowID == requestedID && live.bounds == requestedBounds && live.title == requestedTitle && !live.isMinimized
            }
            if !Task.isCancelled { result = captured }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            previews.refreshPermission()
        }
    }

    @ViewBuilder private func controlLabel(_ title: String, symbol: String) -> some View {
        if width < 260 { Image(systemName: symbol).accessibilityLabel(title) }
        else { Text(title) }
    }

    @ViewBuilder private var previewContent: some View {
        switch result {
        case .image(let image):
            Image(nsImage: image).resizable().scaledToFit()
                .accessibilityLabel("Preview of \(entry.appName), \(entry.title)")
        case .permissionRequired:
            if height < 140 || width < 220 {
                VStack(spacing: 6) {
                    Text("Preview access required").font(.system(size: 10)).multilineTextAlignment(.center)
                    Button("Allow…") { previews.requestPermission() }.controlSize(.small)
                        .accessibilityLabel("Allow Screen Recording for window previews")
                }.padding(8)
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "rectangle.on.rectangle.slash").font(.system(size: 25)).foregroundStyle(.secondary)
                    Text("Window previews need Screen Recording access.").font(.system(size: 12)).multilineTextAlignment(.center)
                    Text("Window switching works without it.").font(.system(size: 10)).foregroundStyle(.secondary)
                    Button("Allow Screen Recording…") { previews.requestPermission() }.controlSize(.small)
                }.padding(14)
            }
        case .unavailable(let message):
            VStack(spacing: 8) {
                if height >= 130 { Image(systemName: "macwindow").font(.system(size: 28)).foregroundStyle(.secondary) }
                Text(message).font(.system(size: width < 220 ? 10 : 12)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineLimit(3)
            }.padding(8)
        case nil:
            ProgressView("Loading preview…").controlSize(.small)
        }
    }
}

/// Settings embeds this view beside the optional preview toggle. Merely opening
/// settings or enabling the feature does not request Screen Recording access.
struct PreviewPermissionView: View {
    @ObservedObject private var previews = WindowPreviewService.shared
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(previews.permissionGranted ? "Screen Recording available" : "Screen Recording optional",
                      systemImage: previews.permissionGranted ? "checkmark.shield" : "hand.raised")
                    .font(.system(size: 12, weight: .medium))
                Text("Previews stay in memory on this Mac. No recording or screenshot files are saved.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(previews.permissionGranted ? "Check access" : "Allow previews…") {
                if previews.permissionGranted { previews.refreshPermission() } else { previews.requestPermission() }
            }.buttonStyle(.bordered)
        }
        .onAppear { previews.refreshPermission() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            previews.refreshPermission()
        }
    }
}
