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

    private static let settleTolerance: CGFloat = 6
    private static let revealInterval: TimeInterval = 0.05
    private static let revealMaxAttempts = 40
    private static let concealDuration: TimeInterval = 0.2

    private var outline: FocusBorderPanel?
    private var revealWork: DispatchWorkItem?
    private var revealAttempts = 0
    private var concealUntil: TimeInterval = 0

    private init() {}

    package func update() {
        revealWork?.cancel()
        revealWork = nil
        revealAttempts = 0
        apply()
    }

    package func concealUntilSettled() {
        revealWork?.cancel()
        revealWork = nil
        revealAttempts = 0
        concealUntil = ProcessInfo.processInfo.systemUptime + Self.concealDuration
        apply()
    }

    package func applyAppearance() {
        outline?.appearance = MenuBarChrome.appearance
        outline?.contentView?.needsDisplay = true
    }

    private func apply() {
        guard let target = targetFrame() else {
            hide()
            return
        }
        let waiting =
            ProcessInfo.processInfo.systemUptime < concealUntil || !isSettled(to: target)
        if waiting {
            hide()
            scheduleReveal()
            return
        }
        show(target)
    }

    private func scheduleReveal() {
        revealAttempts += 1
        if revealAttempts > Self.revealMaxAttempts {
            if let target = targetFrame() {
                show(target)
            }
            return
        }
        let work = DispatchWorkItem { [self] in
            apply()
        }
        revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealInterval, execute: work)
    }

    private func show(_ frame: CGRect) {
        let panel = outline ?? FocusBorderPanel()
        outline = panel
        panel.place(frame)
        panel.orderFront(nil)
    }

    private func hide() {
        outline?.orderOut(nil)
    }

    private func isSettled(to target: CGRect) -> Bool {
        guard let actual = actualFrame() else { return false }
        return abs(actual.origin.x - target.origin.x) <= Self.settleTolerance
            && abs(actual.origin.y - target.origin.y) <= Self.settleTolerance
            && abs(actual.width - target.width) <= Self.settleTolerance
            && abs(actual.height - target.height) <= Self.settleTolerance
    }

    private func actualFrame() -> CGRect? {
        guard let window = focusedWindow() else { return nil }
        guard let ax = window.getFrame() else { return nil }
        let frame = ScreenGeometry.convertRect(ax, screens: WindowManager.screenDescriptors())
        return frame.insetBy(dx: -FocusBorderLayout.width, dy: -FocusBorderLayout.width)
    }

    private func targetFrame() -> CGRect? {
        guard let window = focusedWindow() else { return nil }
        let monitor = WorkspaceManager.shared.focusedMonitor
        if monitor.isFloating(window) {
            return actualFrame()
        }
        let tiled = monitor.workspaces[monitor.active].filter { !monitor.isFloating($0) }
        guard let index = tiled.firstIndex(of: window) else { return nil }
        let frames = Tiler.calculateFrames(
            count: tiled.count,
            screen: monitor.tileFrame,
            layout: monitor.layouts[monitor.active],
            masterRatio: Config.shared.masterRatio
        )
        guard frames.indices.contains(index) else { return nil }
        return ScreenGeometry.convertRect(frames[index], screens: WindowManager.screenDescriptors())
    }

    private func focusedWindow() -> TrackedWindow? {
        let ws = WorkspaceManager.shared
        guard !ws.isTilingPaused, !ws.monitors.isEmpty else { return nil }
        let monitor = ws.focusedMonitor
        guard monitor.workspaces.indices.contains(monitor.active) else { return nil }
        let windows = monitor.workspaces[monitor.active]
        guard !windows.isEmpty else { return nil }
        if let focused = WindowManager.focusedWindow(), windows.contains(focused) {
            return focused
        }
        if monitor.focusedIndices.indices.contains(monitor.active) {
            let index = monitor.focusedIndices[monitor.active]
            if windows.indices.contains(index) {
                return windows[index]
            }
        }
        return windows.first
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
        level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        appearance = MenuBarChrome.appearance
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
        let inner = bounds.insetBy(dx: FocusBorderLayout.width, dy: FocusBorderLayout.width)
        let radius = min(
            Config.shared.borderRadius,
            max(0, inner.width / 2),
            max(0, inner.height / 2)
        )
        MenuBarChrome.accent.setStroke()
        let path = NSBezierPath(roundedRect: inner, xRadius: radius, yRadius: radius)
        path.lineWidth = Config.shared.borderWidth
        path.stroke()
    }
}
