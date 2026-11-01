import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Arrange focus")
struct MonocleFocusTests {
    @Test func focusCycleWrapsAndFallsBackToSavedIndex() {
        #expect(WorkspaceFocusCycle.targetIndex(current: 0, offset: 1, count: 3) == 1)
        #expect(WorkspaceFocusCycle.targetIndex(current: 2, offset: 1, count: 3) == 0)
        #expect(WorkspaceFocusCycle.targetIndex(current: 0, offset: -1, count: 3) == 2)
        #expect(WorkspaceFocusCycle.targetIndex(current: 1, offset: 0, count: 1) == nil)
        #expect(WorkspaceFocusCycle.targetIndex(current: 5, offset: 1, count: 3) == nil)
        #expect(WorkspaceFocusCycle.resolveCurrentIndex(focusedIndex: 2, savedIndex: 0, count: 3) == 2)
        #expect(WorkspaceFocusCycle.resolveCurrentIndex(focusedIndex: nil, savedIndex: 1, count: 3) == 1)
        #expect(WorkspaceFocusCycle.resolveCurrentIndex(focusedIndex: 9, savedIndex: 1, count: 3) == 1)
    }

    @Test func tileVisibilityKeepsMasterAndCapsAtThree() {
        #expect(TileVisibility.visibleIndices(tiledCount: 2, focusedTiledIndex: 1) == [0, 1])
        #expect(TileVisibility.visibleIndices(tiledCount: 3, focusedTiledIndex: 1) == [0, 1, 2])
        #expect(TileVisibility.visibleIndices(tiledCount: 7, focusedTiledIndex: 0) == [0, 1, 2])
        #expect(TileVisibility.visibleIndices(tiledCount: 7, focusedTiledIndex: 2) == [0, 1, 2])
        #expect(TileVisibility.visibleIndices(tiledCount: 7, focusedTiledIndex: 4) == [0, 3, 4])
        #expect(TileVisibility.visibleIndices(tiledCount: 7, focusedTiledIndex: 6) == [0, 5, 6])
    }

    @Test func monocleArrangeShowsEveryTiledWindow() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let plan = ArrangePlanner.plan(
            tileFrame: screen,
            layout: .monocle,
            tiledCount: 7,
            focusedTiledIndex: 2,
            selectedIsTiled: true,
            floatingCount: 1
        )
        #expect(plan.visibleTiledIndices == [0, 1, 2, 3, 4, 5, 6])
        #expect(plan.tiledFrames.count == 7)
        #expect(plan.raiseSelectedAboveFloaters)
    }

    @Test func tileArrangeHidesOverflowBeyondThree() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let plan = ArrangePlanner.plan(
            tileFrame: screen,
            layout: .tile,
            tiledCount: 7,
            focusedTiledIndex: 6,
            selectedIsTiled: true,
            floatingCount: 0
        )
        #expect(plan.visibleTiledIndices == [0, 5, 6])
        #expect(plan.tiledFrames.count == 3)
        #expect(plan.tiledFrames[0].width < screen.width)
        #expect(!plan.raiseSelectedAboveFloaters)
    }
}
