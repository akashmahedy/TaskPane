import Foundation
import CoreGraphics
import Testing
@testable import TaskPaneCore

struct TaskbarGeometryTests {
    @Test func placementStaysReachableAtAllEdgesAndExtremeOffsets() {
        let display = CGRect(x: -1440, y: -300, width: 1440, height: 900)
        for edge in BarEdge.allCases {
            for offset in [-4000.0, 0, 4000] {
                var prefs = BuiltInPreset.windows.preferences
                prefs.barEdge = edge
                prefs.layout.edgeOffset = 1000
                prefs.layout.alongEdgeOffset = offset
                prefs.layout.lengthPercent = 10
                let frame = TaskbarGeometry.frame(in: display, preferences: prefs)
                #expect(display.contains(frame))
                #expect(frame.width > 0 && frame.height > 0)
            }
        }
    }

    @Test func autoHideLeavesOnlyRequestedStripAtEveryPhysicalEdge() {
        let screen = CGRect(x: -1200, y: 0, width: 1200, height: 800)
        for edge in BarEdge.allCases {
            var prefs = BuiltInPreset.windows.preferences
            prefs.barEdge = edge
            let full = TaskbarGeometry.frame(in: screen, preferences: prefs)
            let hidden = TaskbarGeometry.hiddenFrame(full, screen: screen, edge: edge, revealStrip: 7)
            #expect(screen.contains(hidden))
            #expect(hidden.intersection(screen) == hidden)
            let visible = hidden.intersection(screen)
            if edge == .left || edge == .right { #expect(abs(visible.width - 7) < 0.01) }
            else { #expect(abs(visible.height - 7) < 0.01) }
        }
    }

    @Test func paddingChangesEffectiveBarThickness() {
        var prefs = BuiltInPreset.windows.preferences
        prefs.barHeight = 24
        prefs.layout.itemHeight = 80
        prefs.options.verticalPadding = 20
        prefs.options.horizontalPadding = 10
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        #expect(TaskbarGeometry.frame(in: screen, preferences: prefs).height == 120)
        prefs.barEdge = .left
        #expect(TaskbarGeometry.frame(in: screen, preferences: prefs).width == 100)
    }

    @Test func smallestDisplayClampsLargeRequestedBar() {
        var prefs = BuiltInPreset.windows.preferences
        prefs.barHeight = 256
        prefs.layout.itemHeight = 240
        prefs.options.verticalPadding = 100
        let screen = CGRect(x: 0, y: 0, width: 100, height: 80)
        let frame = TaskbarGeometry.frame(in: screen, preferences: prefs)
        #expect(screen.contains(frame))
        #expect(frame.height == 80)
    }
}
