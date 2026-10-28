import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Tile glyph")
struct TileGlyphTests {
    let area = CGRect(x: 0, y: 0, width: 20, height: 12)

    @Test func emptyWorkspaceDrawsNoPanes() {
        #expect(TileGlyph.rects(windowCount: 0, masterRatio: 0.55, in: area).isEmpty)
    }

    @Test func singleWindowFillsTheArea() {
        #expect(TileGlyph.rects(windowCount: 1, masterRatio: 0.55, in: area) == [area])
    }

    @Test func masterFollowsRatioAndStackFillsTheRest() {
        let rects = TileGlyph.rects(windowCount: 2, masterRatio: 0.55, in: area)
        #expect(rects.count == 2)
        #expect(rects[0].width == 10)
        #expect(rects[1].minX == rects[0].maxX + TileGlyph.gap)
        #expect(rects[1].maxX == area.maxX)
        #expect(rects[1].height == area.height)
    }

    @Test func stackSlicesAreCappedAndOrderedTopToBottom() {
        let rects = TileGlyph.rects(windowCount: 9, masterRatio: 0.5, in: area)
        let stack = Array(rects.dropFirst())
        #expect(stack.count == TileGlyph.maxStackSlices)
        #expect(stack[0].maxY == area.maxY)
        #expect(stack.last?.minY == area.minY)
        #expect(zip(stack, stack.dropFirst()).allSatisfy { $0.minY - $1.maxY == TileGlyph.gap })
    }
}
