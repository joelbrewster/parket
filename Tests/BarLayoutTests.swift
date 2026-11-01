import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Bar layout")
struct BarLayoutTests {
    @Test func tileFramePinsBelowBarWhenMenuBarIsHidden() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let tiled = BarLayout.tileFrame(screenFrame: screen, visibleFrame: visible)

        #expect(tiled.origin.x == 0)
        #expect(tiled.origin.y == BarLayout.reservedTop)
        #expect(tiled.width == 1440)
        #expect(tiled.height == 900 - BarLayout.reservedTop)
    }

    @Test func tileFrameIsAtLeastBarHeightWhenMenuBarIsShowing() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 823)
        let tiled = BarLayout.tileFrame(screenFrame: screen, visibleFrame: visible)

        #expect(tiled.origin.y == BarLayout.overlayHeight(menuBar: 25) + BarLayout.gap)
        #expect(tiled.maxY == visible.maxY)
        #expect(tiled.height == visible.maxY - BarLayout.overlayHeight(menuBar: 25) - BarLayout.gap)
    }

    @Test func tileFrameAppliesOutsideSpaceOnLeftRightAndBottom() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let outer: CGFloat = 12
        let tiled = BarLayout.tileFrame(screenFrame: screen, visibleFrame: visible, outer: outer)

        #expect(tiled.minX == outer)
        #expect(tiled.maxX == visible.maxX - outer)
        #expect(tiled.minY == BarLayout.reservedTop + outer)
        #expect(tiled.maxY == visible.maxY - outer)
    }

    @Test func tileFrameFollowsTallerMenuBar() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 37, width: 1440, height: 811)
        let tiled = BarLayout.tileFrame(screenFrame: screen, visibleFrame: visible)

        #expect(tiled.origin.y == BarLayout.overlayHeight(menuBar: 37) + BarLayout.gap)
        #expect(tiled.maxY == visible.maxY)
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
        #expect(BarLayout.reservedTop == BarLayout.height + BarLayout.topPad + BarLayout.gap)
        #expect(BarLayout.gap == 0)
    }
}
