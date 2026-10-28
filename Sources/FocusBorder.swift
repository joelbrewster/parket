import AppKit

package enum FocusBorderLayout {
    package static let width: CGFloat = 2

    package static func windowFrame(from tile: CGRect) -> CGRect {
        tile.insetBy(dx: width, dy: width)
    }

    package static func windowFrames(from tiles: [CGRect]) -> [CGRect] {
        tiles.map(windowFrame(from:))
    }
}

@MainActor
package final class FocusBorder {
    package static let shared = FocusBorder()

    private var panel: FocusBorderPanel?

    private init() {}

    package func update() {
        guard let frame = targetFrame() else {
            panel?.orderOut(nil)
            return
        }
        let border = panel ?? FocusBorderPanel()
        panel = border
        border.place(frame)
        border.orderBack(nil)
    }

    package func applyAppearance() {
        panel?.appearance = MenuBarChrome.appearance
        panel?.contentView?.needsDisplay = true
    }

    private func targetFrame() -> CGRect? {
        let ws = WorkspaceManager.shared
        guard !ws.isTilingPaused, !ws.monitors.isEmpty else { return nil }
        let monitor = ws.focusedMonitor
        guard monitor.workspaces.indices.contains(monitor.active) else { return nil }
        let windows = monitor.workspaces[monitor.active]
        guard !windows.isEmpty else { return nil }

        let index: Int
        if let focused = WindowManager.focusedWindow(),
            let match = windows.firstIndex(where: { $0 == focused })
        {
            index = match
        } else if monitor.focusedIndices.indices.contains(monitor.active) {
            index = monitor.focusedIndices[monitor.active]
        } else {
            index = 0
        }

        let frames = Tiler.calculateFrames(
            count: windows.count,
            screen: monitor.tileFrame,
            layout: monitor.layouts[monitor.active],
            masterRatio: Config.shared.masterRatio
        )
        guard frames.indices.contains(index) else { return nil }
        let window = windows[index]
        if monitor.isFloating(window), let ax = window.getFrame() {
            let frame = ScreenGeometry.convertRect(ax, screens: WindowManager.screenDescriptors())
            return frame.insetBy(dx: -FocusBorderLayout.width, dy: -FocusBorderLayout.width)
        }
        return ScreenGeometry.convertRect(frames[index], screens: WindowManager.screenDescriptors())
    }
}

private final class FocusBorderPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = false
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        hasShadow = false
        isOpaque = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        contentView = FocusBorderView()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(_ frame: CGRect) {
        setFrame(frame, display: true)
        contentView?.needsDisplay = true
    }
}

private final class FocusBorderView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let color = NSColor.controlAccentColor
        guard let gradient = NSGradient(starting: color, ending: color.withAlphaComponent(0)) else {
            color.setFill()
            bounds.fill()
            return
        }
        gradient.draw(in: bounds, angle: -90)
    }
}
