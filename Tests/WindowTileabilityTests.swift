import ApplicationServices
import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Window tileability")
struct WindowTileabilityTests {
    @Test func documentWindowIsTileable() {
        #expect(TileableWindowPolicy.accepts(documentWindow()))
        #expect(TileableWindowPolicy.rejectionReasons(documentWindow()).isEmpty)
    }

    @Test func standardOverlayWithoutWindowControlsIsNotTileable() {
        var attributes = documentWindow()
        attributes.hasCloseButton = false
        attributes.hasMinimizeButton = false
        attributes.hasZoomButton = false

        #expect(!TileableWindowPolicy.accepts(attributes))
        #expect(
            TileableWindowPolicy.rejectionReasons(attributes) == [
                .missingCloseButton,
                .missingMinimizeButton,
                .missingZoomButton,
            ])
    }

    @Test func fixedSizeStandardDialogIsNotTileable() {
        var attributes = documentWindow()
        attributes.canSetSize = false

        #expect(!TileableWindowPolicy.accepts(attributes))
        #expect(TileableWindowPolicy.rejectionReasons(attributes) == [.sizeNotSettable])
    }

    @Test func modalStandardWindowIsNotTileable() {
        var attributes = documentWindow()
        attributes.modal = true

        #expect(!TileableWindowPolicy.accepts(attributes))
        #expect(TileableWindowPolicy.rejectionReasons(attributes) == [.modal])
    }

    @Test func smallPanelsAutoFloatButNormalWindowsDoNot() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let panel = CGRect(x: 100, y: 100, width: 420, height: 320)
        let settings = CGRect(x: 100, y: 100, width: 780, height: 640)
        let browser = CGRect(x: 0, y: 0, width: 1200, height: 900)
        #expect(AutoFloatPolicy.shouldFloat(frame: panel, screen: screen))
        #expect(!AutoFloatPolicy.shouldFloat(frame: settings, screen: screen))
        #expect(!AutoFloatPolicy.shouldFloat(frame: browser, screen: screen))
    }

    @Test func pictureInPictureTitlesAutoFloat() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = CGRect(x: 40, y: 40, width: 1200, height: 800)
        #expect(AutoFloatPolicy.shouldFloat(frame: frame, screen: screen, title: "Picture in Picture"))
        #expect(AutoFloatPolicy.isPictureInPicture(title: "Picture-in-Picture"))
        #expect(!AutoFloatPolicy.isPictureInPicture(title: "Safari"))
    }

    private func documentWindow() -> TileableWindowAttributes {
        TileableWindowAttributes(
            role: kAXWindowRole as String,
            subrole: kAXStandardWindowSubrole as String,
            minimized: false,
            fullscreen: false,
            modal: false,
            hasCloseButton: true,
            hasMinimizeButton: true,
            hasZoomButton: true,
            canSetPosition: true,
            canSetSize: true
        )
    }
}
