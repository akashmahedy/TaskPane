import Foundation
import CoreGraphics

/// Pure, display-relative geometry shared by the live controller and regression tests.
public enum TaskbarGeometry {
    public static func frame(in display: CGRect, preferences: TaskPanePreferences) -> CGRect {
        let layout = preferences.layout
        let options = preferences.options
        let vertical = preferences.barEdge == .left || preferences.barEdge == .right
        let dimension = vertical ? display.height : display.width
        let crossDimension = vertical ? display.width : display.height
        let padding = vertical ? options.horizontalPadding : options.verticalPadding
        let thickness = min(crossDimension, max(preferences.barHeight, layout.itemHeight + padding * 2))
        let inset = min(max(0, crossDimension - thickness), layout.edgeOffset)
        let length = min(dimension, max(1, dimension * layout.lengthPercent / 100))
        let origin = vertical ? display.minY : display.minX
        let start: CGFloat
        switch layout.alignment {
        case .leading: start = origin
        case .center: start = origin + (dimension - length) / 2
        case .trailing: start = origin + dimension - length
        }
        let along = min(origin + dimension - length, max(origin, start + layout.alongEdgeOffset))
        switch preferences.barEdge {
        case .bottom: return CGRect(x: along, y: display.minY + inset, width: length, height: thickness)
        case .top: return CGRect(x: along, y: display.maxY - thickness - inset, width: length, height: thickness)
        case .left: return CGRect(x: display.minX + inset, y: along, width: thickness, height: length)
        case .right: return CGRect(x: display.maxX - thickness - inset, y: along, width: thickness, height: length)
        }
    }

    /// A clipped host lets the panel shrink to a strip within its owning display;
    /// no hidden content is moved onto an adjacent monitor.
    public static func hiddenFrame(_ full: CGRect, screen: CGRect, edge: BarEdge, revealStrip: Double) -> CGRect {
        var hidden = full
        let strip = min(max(1, revealStrip), edge == .left || edge == .right ? full.width : full.height)
        switch edge {
        case .bottom: hidden.origin.y = screen.minY; hidden.size.height = strip
        case .top: hidden.origin.y = screen.maxY - strip; hidden.size.height = strip
        case .left: hidden.origin.x = screen.minX; hidden.size.width = strip
        case .right: hidden.origin.x = screen.maxX - strip; hidden.size.width = strip
        }
        return hidden
    }
}
