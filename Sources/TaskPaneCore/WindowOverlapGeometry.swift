import Foundation
import CoreGraphics

/// Global Core Graphics / Accessibility coordinates (the vertical axis points down).
public struct WindowOverlapReservation: Equatable {
    public let displayBounds: CGRect
    public let barBounds: CGRect
    public let edge: BarEdge

    public init(displayBounds: CGRect, barBounds: CGRect, edge: BarEdge) {
        self.displayBounds = displayBounds
        self.barBounds = barBounds
        self.edge = edge
    }
}

public enum WindowOverlapGeometry {
    /// Keeps the opposite edge fixed and removes just the overlapping strip.
    /// Never expands a window or produces a tiny, unusable result. A window
    /// spanning displays belongs to the display containing most of its area.
    public static func avoidingOverlap(frame: CGRect, reservations: [WindowOverlapReservation],
                                       minimumSize: CGSize = CGSize(width: 240, height: 160)) -> CGRect? {
        guard valid(frame), minimumSize.width.isFinite, minimumSize.height.isFinite,
              minimumSize.width > 0, minimumSize.height > 0 else { return nil }
        let validReservations = reservations.filter { valid($0.displayBounds) && valid($0.barBounds) }
        guard let reservation = validReservations.max(by: {
            area(frame.intersection($0.displayBounds)) < area(frame.intersection($1.displayBounds))
        }), area(frame.intersection(reservation.displayBounds)) >= area(frame) / 2 else { return nil }
        let bar = reservation.barBounds.intersection(reservation.displayBounds)
        let overlap = frame.intersection(bar)
        guard !overlap.isNull, overlap.width > 0.5, overlap.height > 0.5 else { return nil }
        var result = frame
        switch reservation.edge {
        case .bottom:
            result.size.height = min(frame.height, bar.minY - frame.minY)
        case .top:
            result.origin.y = max(frame.minY, bar.maxY)
            result.size.height = frame.maxY - result.minY
        case .left:
            result.origin.x = max(frame.minX, bar.maxX)
            result.size.width = frame.maxX - result.minX
        case .right:
            result.size.width = min(frame.width, bar.minX - frame.minX)
        }
        guard valid(result), result.width >= minimumSize.width, result.height >= minimumSize.height,
              !approximatelyEqual(result, frame) else { return nil }
        return result
    }

    public static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 2) -> Bool {
        valid(lhs) && valid(rhs) && tolerance.isFinite && tolerance >= 0 &&
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance &&
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    private static func valid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && frame.minX.isFinite && frame.minY.isFinite &&
        frame.width.isFinite && frame.height.isFinite && frame.width > 0 && frame.height > 0
    }

    private static func area(_ frame: CGRect) -> CGFloat {
        valid(frame) ? frame.width * frame.height : 0
    }
}
