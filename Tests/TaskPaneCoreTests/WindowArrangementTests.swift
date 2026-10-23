import Testing
@testable import TaskPaneCore

struct WindowArrangementTests {
    private let items = [
        WindowArrangementItem(id: "a1", applicationKey: "A"),
        WindowArrangementItem(id: "b1", applicationKey: "B"),
        WindowArrangementItem(id: "a2", applicationKey: "A"),
        WindowArrangementItem(id: "c1", applicationKey: "C"),
        WindowArrangementItem(id: "b2", applicationKey: "B")
    ]

    @Test func separateWindowsKeepBaseOrderAndAdjacencyKeepsEveryWindow() {
        #expect(WindowArrangement.ordered(items: items, manualOrder: [], groupAdjacent: false) == ["a1", "b1", "a2", "c1", "b2"])
        #expect(WindowArrangement.ordered(items: items, manualOrder: [], groupAdjacent: true) == ["a1", "a2", "b1", "b2", "c1"])
        let crowded = (0..<15).map { WindowArrangementItem(id: "\($0)", applicationKey: $0.isMultiple(of: 2) ? "A" : "B") }
        let ordered = WindowArrangement.ordered(items: crowded, manualOrder: [], groupAdjacent: true)
        #expect(ordered.count == crowded.count)
        #expect(Set(ordered) == Set(crowded.map(\.id)))
    }

    @Test func manualWindowOrderControlsBlocksAndOrderWithinAnApp() {
        let manual = ["b2", "a2", "a1", "closed", "b2"]
        #expect(WindowArrangement.ordered(items: items, manualOrder: manual, groupAdjacent: false) == ["b2", "a2", "a1", "b1", "c1"])
        #expect(WindowArrangement.ordered(items: items, manualOrder: manual, groupAdjacent: true) == ["b2", "b1", "a2", "a1", "c1"])
    }

    @Test func newWindowsAppendToTheirAppWithoutReorderingKnownWindows() {
        let expanded = items + [WindowArrangementItem(id: "a3", applicationKey: "A")]
        let order = WindowArrangement.ordered(items: expanded, manualOrder: ["c1", "a2", "a1", "b2", "b1"], groupAdjacent: true)
        #expect(order == ["c1", "a2", "a1", "a3", "b2", "b1"])
    }

    @Test func reconciliationRetainsHiddenLiveWindowsAndPrunesClosedOnes() {
        #expect(WindowArrangement.reconciled(["hidden", "a2", "closed", "a2"], liveIDs: ["a1", "a2", "hidden", "new", "new"]) == ["hidden", "a2", "a1", "new"])
        #expect(WindowArrangement.reconciled(["closed"], liveIDs: []) == [])
        #expect(WindowArrangement.ordered(items: [], manualOrder: ["closed"], groupAdjacent: true) == [])
    }

    @Test func duplicateInputIdentityUsesOnlyItsFirstApplication() {
        let duplicate = items + [WindowArrangementItem(id: "a1", applicationKey: "different")]
        #expect(WindowArrangement.ordered(items: duplicate, manualOrder: [], groupAdjacent: true) == ["a1", "a2", "b1", "b2", "c1"])
    }

    @Test func draggingMovesAnIndividualWindowRatherThanItsWholeApp() {
        let current = ["a1", "a2", "b1", "hidden"]
        #expect(WindowArrangement.moving("a2", before: "a1", currentOrder: current) == ["a2", "a1", "b1", "hidden"])
        #expect(WindowArrangement.moving("b1", before: "a2", currentOrder: current) == ["a1", "b1", "a2", "hidden"])
        #expect(WindowArrangement.moving("a1", before: nil, currentOrder: current) == ["a2", "b1", "hidden", "a1"])
        #expect(current == ["a1", "a2", "b1", "hidden"])
    }

    @Test func invalidAndNoOpDropsCannotInventWindows() {
        let current = ["a1", "a2", "b1"]
        #expect(WindowArrangement.moving("a1", before: "a1", currentOrder: current) == nil)
        #expect(WindowArrangement.moving("missing", before: "a1", currentOrder: current) == nil)
        #expect(WindowArrangement.moving("a1", before: "missing", currentOrder: current) == nil)
        #expect(WindowArrangement.moving("a1", before: "a2", currentOrder: current) == nil)
        #expect(WindowArrangement.moving("b1", before: nil, currentOrder: current) == nil)
        #expect(WindowArrangement.moving("a1", before: nil, currentOrder: []) == nil)
    }

    @Test func filteredDragsPreserveHiddenWindowsAndUseDisplayedOrder() {
        let global = ["A", "H", "B", "C"]
        #expect(WindowArrangement.moving("C", before: "A", currentOrder: ["A", "B", "C"],
                                         retainedOrder: global, liveIDs: global) == ["C", "A", "H", "B"])
        #expect(WindowArrangement.moving("A", before: "C", currentOrder: ["C", "B", "A"],
                                         retainedOrder: global, liveIDs: global) == ["A", "C", "H", "B"])
    }

    @Test func filteredDragsRejectHiddenTargetsAndStaleSources() {
        let live = ["A", "H", "B", "C"]
        #expect(WindowArrangement.moving("A", before: "H", currentOrder: ["A", "B", "C"],
                                         retainedOrder: live, liveIDs: live) == nil)
        #expect(WindowArrangement.moving("closed", before: "A", currentOrder: ["closed", "A", "B"],
                                         retainedOrder: ["closed"] + live, liveIDs: live) == nil)
        #expect(WindowArrangement.moving("C", before: "A", currentOrder: ["A", "A", "B", "C", "closed"],
                                         retainedOrder: ["closed"] + live, liveIDs: live) == ["C", "A", "H", "B"])
    }

    @Test func appBlocksMoveForwardAndBackwardWithoutReversingTheirWindows() {
        let order = ["A1", "A2", "B1", "B2", "C1", "C2"]
        #expect(WindowArrangement.movingBlock(["A1", "A2"], before: "C1", currentOrder: order,
                                              retainedOrder: order, liveIDs: order) == ["B1", "B2", "A1", "A2", "C1", "C2"])
        #expect(WindowArrangement.movingBlock(["C1", "C2"], before: "A1", currentOrder: order,
                                              retainedOrder: order, liveIDs: order) == ["C1", "C2", "A1", "A2", "B1", "B2"])
        #expect(WindowArrangement.movingBlock(["A2", "A1"], before: nil, currentOrder: order,
                                              retainedOrder: order, liveIDs: order) == ["B1", "B2", "C1", "C2", "A1", "A2"])
    }

    @Test func appBlockMoveIncludesHiddenSiblingsAndPreservesOtherHiddenWindows() {
        let global = ["A1", "hidden-A", "B1", "A2", "hidden-B", "C1"]
        let displayed = ["A1", "B1", "A2", "C1"]
        #expect(WindowArrangement.movingBlock(["A1", "A2", "hidden-A"], before: "C1", currentOrder: displayed,
                                              retainedOrder: global, liveIDs: global) == ["B1", "hidden-B", "A1", "hidden-A", "A2", "C1"])
    }

    @Test func appBlockMoveStartsFromCurrentDisplayOrder() {
        let retained = ["A1", "A2", "hidden", "B1", "B2", "C1"]
        let displayed = ["C1", "B2", "B1", "A2", "A1"]
        #expect(WindowArrangement.movingBlock(["A1", "A2"], before: "B2", currentOrder: displayed,
                                              retainedOrder: retained, liveIDs: retained) == ["C1", "A2", "A1", "B2", "hidden", "B1"])
    }

    @Test func invalidOrNoOpBlockMovesCannotChangeOtherWindows() {
        let order = ["A1", "A2", "B1", "B2"]
        for ids in [[], ["missing"], ["A1", "missing"]] {
            #expect(WindowArrangement.movingBlock(ids, before: "B1", currentOrder: order,
                                                  retainedOrder: order, liveIDs: order) == nil)
        }
        for target in ["A1", "A2", "missing", "B1"] {
            #expect(WindowArrangement.movingBlock(["A1", "A2"], before: target, currentOrder: order,
                                                  retainedOrder: order, liveIDs: order) == nil)
        }
        #expect(WindowArrangement.movingBlock(["B1", "B2"], before: nil, currentOrder: order,
                                              retainedOrder: order, liveIDs: order) == nil)
        #expect(WindowArrangement.movingBlock(["B1", "B2"], before: "A1", currentOrder: ["A1", "A2"],
                                              retainedOrder: order, liveIDs: order) == nil)
    }
}
