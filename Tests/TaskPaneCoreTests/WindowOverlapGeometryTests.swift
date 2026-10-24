import Foundation
import CoreGraphics
import Testing
@testable import TaskPaneCore

struct WindowOverlapGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func eachEdgeKeepsTheOppositeEdgeFixed() {
        let frame = CGRect(x: 10, y: 10, width: 1420, height: 880)
        let cases: [(BarEdge, CGRect, CGRect)] = [
            (.bottom, CGRect(x: 0, y: 850, width: 1440, height: 50), CGRect(x: 10, y: 10, width: 1420, height: 840)),
            (.top, CGRect(x: 0, y: 0, width: 1440, height: 50), CGRect(x: 10, y: 50, width: 1420, height: 840)),
            (.left, CGRect(x: 0, y: 0, width: 50, height: 900), CGRect(x: 50, y: 10, width: 1380, height: 880)),
            (.right, CGRect(x: 1390, y: 0, width: 50, height: 900), CGRect(x: 10, y: 10, width: 1380, height: 880))
        ]
        for (edge, bar, expected) in cases {
            let reservation = WindowOverlapReservation(displayBounds: screen, barBounds: bar, edge: edge)
            #expect(WindowOverlapGeometry.avoidingOverlap(frame: frame, reservations: [reservation]) == expected)
            #expect(WindowOverlapGeometry.avoidingOverlap(frame: expected, reservations: [reservation]) == nil)
        }
    }

    @Test func doesNotResizeNonoverlappingWindowsOrProduceUnusableSizes() {
        let reservation = WindowOverlapReservation(displayBounds: screen, barBounds: CGRect(x: 300, y: 850, width: 800, height: 50), edge: .bottom)
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: CGRect(x: 0, y: 800, width: 250, height: 100), reservations: [reservation]) == nil)
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: CGRect(x: 400, y: 800, width: 400, height: 100), reservations: [reservation]) == nil)
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: .null, reservations: [reservation]) == nil)
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: CGRect(x: CGFloat.nan, y: 0, width: 400, height: 400), reservations: [reservation]) == nil)
    }

    @Test func coordinatesSupportScreensAboveOrLeftOfTheMainDisplay() {
        let negativeScreen = CGRect(x: -1440, y: -900, width: 1440, height: 900)
        let reservation = WindowOverlapReservation(displayBounds: negativeScreen, barBounds: CGRect(x: -1440, y: -50, width: 1440, height: 50), edge: .bottom)
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: CGRect(x: -1400, y: -850, width: 1200, height: 850), reservations: [reservation]) == CGRect(x: -1400, y: -850, width: 1200, height: 800))
    }

    @Test func spanningWindowUsesItsMajorityDisplayAndRestoreComparisonRejectsUserMoves() {
        let main = WindowOverlapReservation(displayBounds: screen, barBounds: CGRect(x: 0, y: 850, width: 1440, height: 50), edge: .bottom)
        let second = WindowOverlapReservation(displayBounds: CGRect(x: 1440, y: 0, width: 1440, height: 900), barBounds: CGRect(x: 1440, y: 800, width: 1440, height: 100), edge: .bottom)
        let frame = CGRect(x: 1300, y: 100, width: 1000, height: 800)
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: frame, reservations: [main, second]) == CGRect(x: 1300, y: 100, width: 1000, height: 700))
        #expect(WindowOverlapGeometry.avoidingOverlap(frame: frame, reservations: [main]) == nil)
        #expect(WindowOverlapGeometry.approximatelyEqual(frame, frame.offsetBy(dx: 1, dy: -1)))
        #expect(!WindowOverlapGeometry.approximatelyEqual(frame, frame.offsetBy(dx: 10, dy: 0)))
    }
}
