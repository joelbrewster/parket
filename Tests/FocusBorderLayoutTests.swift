import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Focus border layout")
struct FocusBorderLayoutTests {
    @Test func windowFrameInsetsByBorderWidth() {
        let tile = CGRect(x: 10, y: 20, width: 400, height: 300)
        let window = FocusBorderLayout.windowFrame(from: tile)
        let inset = FocusBorderLayout.width
        #expect(
            window
                == CGRect(
                    x: tile.minX + inset,
                    y: tile.minY + inset,
                    width: tile.width - inset * 2,
                    height: tile.height - inset * 2
                )
        )
    }
}
