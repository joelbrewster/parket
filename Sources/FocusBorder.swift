import AppKit

package enum FocusBorderLayout {
    package static let width: CGFloat = 4

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

    private var fill: FocusBorderPanel?
    private var outline: FocusBorderPanel?

    private init() {}

    package func update() {
        guard let frame = targetFrame() else {
            fill?.orderOut(nil)
            outline?.orderOut(nil)
            return
        }
        let fillPanel = fill ?? FocusBorderPanel(role: .fill)
        let outlinePanel = outline ?? FocusBorderPanel(role: .outline)
        fill = fillPanel
        outline = outlinePanel
        fillPanel.place(frame)
        outlinePanel.place(frame)
        fillPanel.orderBack(nil)
        outlinePanel.orderFront(nil)
    }

    package func applyAppearance() {
        let appearance = MenuBarChrome.appearance
        for panel in [fill, outline] {
            panel?.appearance = appearance
            panel?.contentView?.needsDisplay = true
        }
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

private enum FocusBorderRole {
    case fill
    case outline
}

private final class FocusBorderPanel: NSPanel {
    init(role: FocusBorderRole) {
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
        let base = NSWindow.Level.normal.rawValue
        level = NSWindow.Level(rawValue: role == .fill ? base - 1 : base + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        appearance = MenuBarChrome.appearance
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        contentView = FocusBorderView(role: role)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(_ frame: CGRect) {
        setFrame(frame, display: true)
        contentView?.needsDisplay = true
    }
}

private final class FocusBorderView: NSView {
    private let role: FocusBorderRole

    init(role: FocusBorderRole) {
        self.role = role
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let color = NSColor.controlAccentColor
        switch role {
        case .fill:
            color.setFill()
            bounds.fill()
        case .outline:
            color.withAlphaComponent(0.55).setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 6
            path.stroke()
        }
    }
}
