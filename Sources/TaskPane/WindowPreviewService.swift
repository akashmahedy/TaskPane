import AppKit
import Combine
import CoreGraphics
import ScreenCaptureKit

/// Captures only the window explicitly associated with an existing AX session.
/// No stream, file, screen-wide fallback, or background screenshot collection is
/// created. Missing or ambiguous capture identity remains an unavailable preview.
@MainActor
final class WindowPreviewService: ObservableObject {
    static let shared = WindowPreviewService()

    @Published private(set) var permissionGranted = CGPreflightScreenCaptureAccess()

    enum Preview {
        case image(NSImage)
        case permissionRequired
        case unavailable(String)
    }

    private struct Key: Hashable {
        let sessionID: UInt32
        let pid: Int32
        let windowID: CGWindowID
        let width: Int
        let height: Int
    }

    private struct CachedImage {
        let image: NSImage
        let bounds: CGRect
        let title: String
        let createdAt: TimeInterval
    }

    private var cache: [Key: CachedImage] = [:]
    private var capturing = false

    private init() {}

    /// Preflight is read-only and never triggers a permission request.
    func refreshPermission() {
        permissionGranted = CGPreflightScreenCaptureAccess()
        if !permissionGranted { cache.removeAll() }
    }

    /// Called only by an explicit permission button, never by a hover or toggle.
    func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
        refreshPermission()
    }

    func clear() { cache.removeAll() }

    func preview(for entry: WindowEntry, width: Double, height: Double,
                 stillValid: @MainActor () -> Bool) async -> Preview {
        refreshPermission()
        guard permissionGranted else { return .permissionRequired }
        guard !Task.isCancelled, stillValid() else { return .unavailable("This window is no longer available.") }
        guard !entry.isMinimized else { return .unavailable("Restore this window to see a fresh preview.") }
        guard let windowID = entry.captureWindowID, windowID != kCGNullWindowID else {
            return .unavailable("This window does not have an unambiguous preview identity.")
        }
        let pixelsWide = Int(min(1536, max(64, width.isFinite ? width * 2 : 560)))
        let pixelsHigh = Int(min(1024, max(64, height.isFinite ? height * 2 : 360)))
        let key = Key(sessionID: entry.id, pid: entry.pid, windowID: windowID,
                      width: pixelsWide, height: pixelsHigh)
        let now = ProcessInfo.processInfo.systemUptime
        cache = cache.filter { now - $0.value.createdAt < 2 }
        if let cached = cache[key], cached.bounds == entry.bounds, cached.title == entry.title {
            return .image(cached.image)
        }
        // A cancelled ScreenCaptureKit call may still be finishing. Do not queue
        // another capture behind it or let a rapid pointer sweep collect windows.
        guard !capturing else { return .unavailable("Move back to this window to refresh its preview.") }
        capturing = true
        defer { capturing = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard !Task.isCancelled, stillValid(), CGPreflightScreenCaptureAccess() else {
                return .unavailable("The preview request is no longer active.")
            }
            let matches = content.windows.filter {
                $0.windowID == windowID && $0.owningApplication?.processID == entry.pid && $0.windowLayer == 0
            }
            guard matches.count == 1, let window = matches.first,
                  Self.sameFrame(window.frame, entry.bounds), window.frame.width > 1, window.frame.height > 1,
                  window.title.map({ $0.isEmpty || $0 == entry.title }) ?? true else {
                return .unavailable("This window changed. Wait for the taskbar to refresh.")
            }
            // Capture the associated ID only. A similarly titled window is never
            // substituted if that ID is missing, moved, closed, or reused.
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            let scale = min(Double(pixelsWide) / window.frame.width, Double(pixelsHigh) / window.frame.height)
            configuration.width = max(1, Int((window.frame.width * scale).rounded()))
            configuration.height = max(1, Int((window.frame.height * scale).rounded()))
            configuration.showsCursor = false
            configuration.scalesToFit = true
            configuration.ignoreShadowsSingleWindow = true
            let captured = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            guard !Task.isCancelled, stillValid(), CGPreflightScreenCaptureAccess() else {
                return .unavailable("The preview request is no longer active.")
            }
            let image = NSImage(cgImage: captured, size: NSSize(width: CGFloat(captured.width), height: CGFloat(captured.height)))
            if cache.count >= 8, let oldest = cache.min(by: { $0.value.createdAt < $1.value.createdAt })?.key {
                cache.removeValue(forKey: oldest)
            }
            cache[key] = CachedImage(image: image, bounds: entry.bounds, title: entry.title,
                                     createdAt: ProcessInfo.processInfo.systemUptime)
            return .image(image)
        } catch {
            refreshPermission()
            return permissionGranted ? .unavailable("macOS could not provide this window preview.") : .permissionRequired
        }
    }

    private static func sameFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 3 && abs(lhs.minY - rhs.minY) <= 3 &&
        abs(lhs.width - rhs.width) <= 3 && abs(lhs.height - rhs.height) <= 3
    }
}
