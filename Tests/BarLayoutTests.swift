import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Bar layout")
struct BarLayoutTests {
    @Test func tileFramePinsBelowBarAndGapFromScreenTop() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let tiled = BarLayout.tileFrame(screenFrame: screen, visibleFrame: visible)

        #expect(tiled.origin.x == 0)
        #expect(tiled.origin.y == BarLayout.reservedTop)
        #expect(tiled.width == 1440)
        #expect(tiled.height == 900 - BarLayout.reservedTop)
    }

    @Test func tileFrameKeepsDockInsetFromVisibleBottom() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 848)
        let tiled = BarLayout.tileFrame(screenFrame: screen, visibleFrame: visible)

        #expect(tiled.origin.y == BarLayout.reservedTop)
        #expect(tiled.maxY == visible.maxY)
        #expect(tiled.height == 848 - BarLayout.reservedTop)
    }

    @Test func reservedTopIsBarPlusTinyGap() {
        #expect(BarLayout.reservedTop == BarLayout.height + BarLayout.gap)
        #expect(BarLayout.gap == 4)
    }
}
