import AppKit

package enum DesktopOverlayMode: String, Equatable {
    case center
    case tile
    case fill
}

@MainActor
package final class DesktopOverlay {
    package static let shared = DesktopOverlay()

    private var panels: [CGDirectDisplayID: DesktopOverlayPanel] = [:]
    private var image: NSImage?
    private var started = false

    private init() {}

    package func start() {
        started = true
        reload()
    }

    package func reload() {
        image = loadImage()
        sync(screens: NSScreen.screens)
    }

    package func sync(screens: [NSScreen]) {
        guard started else { return }
        let ids = Set(screens.map { WindowManager.displayID(for: $0) })
        for id in panels.keys where !ids.contains(id) {
            panels.removeValue(forKey: id)?.orderOut(nil)
        }
        for screen in screens {
            let id = WindowManager.displayID(for: screen)
            let panel = panels[id] ?? DesktopOverlayPanel()
            panel.place(on: screen, image: image, mode: Config.shared.desktopOverlayMode)
            panel.orderFrontRegardless()
            panels[id] = panel
        }
    }

    package func applyAppearance() {
        for panel in panels.values {
            panel.appearance = MenuBarChrome.appearance
            panel.refresh()
        }
    }

    private func loadImage() -> NSImage? {
        let path = Config.shared.desktopOverlay
        guard !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path),
            let image = NSImage(contentsOf: url),
            image.isValid
        else { return nil }
        return image
    }
}

private final class DesktopOverlayPanel: NSPanel {
    private let content = DesktopOverlayView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        hasShadow = false
        isOpaque = true
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        backgroundColor = MenuBarChrome.color
        appearance = MenuBarChrome.appearance
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(on screen: NSScreen, image: NSImage?, mode: DesktopOverlayMode) {
        setFrame(screen.frame, display: true)
        backgroundColor = MenuBarChrome.color
        content.image = image
        content.mode = mode
        content.needsDisplay = true
    }

    func refresh() {
        backgroundColor = MenuBarChrome.color
        content.needsDisplay = true
    }
}

private final class DesktopOverlayView: NSView {
    var image: NSImage?
    var mode: DesktopOverlayMode = .center

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        MenuBarChrome.color.setFill()
        bounds.fill()
        guard let image else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        switch mode {
        case .center:
            drawCentered(image)
        case .tile:
            drawTiled(image)
        case .fill:
            drawFilled(image)
        }
    }

    private func drawCentered(_ image: NSImage) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        draw(
            image,
            in: CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            ))
    }

    private func drawTiled(_ image: NSImage) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        var y = bounds.minY
        while y < bounds.maxY {
            var x = bounds.minX
            while x < bounds.maxX {
                draw(image, in: CGRect(x: x, y: y, width: size.width, height: size.height))
                x += size.width
            }
            y += size.height
        }
    }

    private func drawFilled(_ image: NSImage) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = max(bounds.width / size.width, bounds.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        draw(
            image,
            in: CGRect(
                x: bounds.midX - width / 2,
                y: bounds.midY - height / 2,
                width: width,
                height: height
            ))
    }

    private func draw(_ image: NSImage, in rect: CGRect) {
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}
