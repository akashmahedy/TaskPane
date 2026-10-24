import AppKit
import SwiftUI

extension View {
    /// Keep the native drag source on the Button's label, where mouse dragging begins.
    @ViewBuilder func taskPaneDrag(enabled: Bool, payload: String) -> some View {
        if enabled { onDrag { NSItemProvider(object: payload as NSString) } }
        else { self }
    }

    func taskPaneMiddleClick(enabled: Bool, action: @escaping () -> Void) -> some View {
        background(MiddleClickRegion(enabled: enabled, action: action).allowsHitTesting(false))
    }
}

private struct MiddleClickRegion: NSViewRepresentable {
    var enabled: Bool
    let action: () -> Void
    func makeNSView(context: Context) -> MiddleClickView { MiddleClickView() }
    func updateNSView(_ view: MiddleClickView, context: Context) {
        view.enabled = enabled
        view.action = action
    }
    static func dismantleNSView(_ view: MiddleClickView, coordinator: ()) { view.removeMonitor() }
}

private final class MiddleClickView: NSView {
    var enabled = false
    var action: (() -> Void)?
    private var monitor: Any?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
            guard let self, self.enabled, event.buttonNumber == 2,
                  let window = self.window, event.window === window,
                  !self.isHiddenOrHasHiddenAncestor,
                  self.visibleRect.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
            self.action?()
            return nil
        }
    }
    func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
    deinit { removeMonitor() }
}
