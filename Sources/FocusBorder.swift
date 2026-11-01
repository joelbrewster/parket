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

    private static let settleTolerance: CGFloat = 10
    private static let idleDelay: TimeInterval = 0.12
    private static let fadeInDuration: TimeInterval = 0.1
    private static let fadeOutDuration: TimeInterval = 0.06
    private static let maxSettleAttempts = 20

    private var panel: FocusBorderPanel?
    private let revealDebounce = Debounce()
    private var generation: UInt64 = 0
    private var settleAttempts = 0
    private var dragging = false
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    package func start() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDragged, .leftMouseUp,
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated {
                FocusBorder.shared.handleMouse(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            FocusBorder.shared.handleMouse(event)
            return event
        }
        reveal()
    }

    package func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        dragging = false
        cancelReveal()
        hide(animated: false)
        panel?.orderOut(nil)
    }

    package func update() {
        if dragging {
            hide(animated: true)
            return
        }
        reveal()
    }

    package func concealUntilSettled() {
        if dragging {
            hide(animated: true)
            return
        }
        hide(animated: true)
        scheduleReveal()
    }

    package func applyAppearance() {
        panel?.appearance = MenuBarChrome.appearance
        panel?.contentView?.needsDisplay = true
    }

    private func handleMouse(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            if dragging { return }
            beginDrag()
        case .leftMouseUp:
            guard dragging else { return }
            endDrag()
        default:
            break
        }
    }

    private func beginDrag() {
        dragging = true
        cancelReveal()
        hide(animated: true)
    }

    private func endDrag() {
        dragging = false
        scheduleReveal()
    }

    private func reveal() {
        cancelReveal()
        settleAttempts = 0
        tryShow()
    }

    private func scheduleReveal() {
        cancelReveal()
        settleAttempts = 0
        revealDebounce.schedule(after: Self.idleDelay) { [self] in
            tryShow()
        }
    }

    private func cancelReveal() {
        revealDebounce.cancel()
        generation &+= 1
    }

    private func tryShow() {
        if dragging {
            hide(animated: true)
            return
        }
        guard let actual = actualWindowFrame() else {
            hide(animated: true)
            return
        }
        if let tile = tileTargetFrame(), !near(actual, tile) {
            settleAttempts += 1
            if settleAttempts <= Self.maxSettleAttempts {
                hide(animated: true)
                revealDebounce.schedule(after: Self.idleDelay) { [self] in
                    tryShow()
                }
                return
            }
        }
        let screens = WindowManager.screenDescriptors()
        show(
            ScreenGeometry.convertRect(actual, screens: screens).insetBy(
                dx: -FocusBorderLayout.width,
                dy: -FocusBorderLayout.width
            ))
    }

    private func show(_ frame: CGRect) {
        let panel = self.panel ?? FocusBorderPanel()
        self.panel = panel
        panel.place(frame)
        panel.orderFrontRegardless()
        let gen = generation
        if panel.alphaValue > 0.95 {
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1
        } completionHandler: {
            MainActor.assumeIsolated {
                guard gen == FocusBorder.shared.generation else { return }
                panel.alphaValue = 1
            }
        }
    }

    private func hide(animated: Bool) {
        guard let panel else { return }
        let gen = generation
        if !animated {
            panel.alphaValue = 0
            return
        }
        guard panel.alphaValue > 0.01 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeOutDuration
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                guard gen == FocusBorder.shared.generation else { return }
                panel.alphaValue = 0
            }
        }
    }

    private func near(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= Self.settleTolerance
            && abs(lhs.origin.y - rhs.origin.y) <= Self.settleTolerance
            && abs(lhs.width - rhs.width) <= Self.settleTolerance
            && abs(lhs.height - rhs.height) <= Self.settleTolerance
    }

    private func actualWindowFrame() -> CGRect? {
        focusedWindow()?.getFrame()
    }

    private func tileTargetFrame() -> CGRect? {
        guard let window = focusedWindow() else { return nil }
        let ws = WorkspaceManager.shared
        let monitor = ws.monitors.first { $0.containsWindow(window) } ?? ws.focusedMonitor
        return monitor.placedFrame(for: window)
    }

    private func focusedWindow() -> TrackedWindow? {
        let ws = WorkspaceManager.shared
        guard !ws.isTilingPaused, !ws.monitors.isEmpty else { return nil }
        if let focused = WindowManager.focusedWindow(),
            ws.monitors.contains(where: { $0.containsWindow(focused) })
        {
            return focused
        }
        let monitor = ws.focusedMonitor
        guard monitor.workspaces.indices.contains(monitor.active) else { return nil }
        let windows = monitor.workspaces[monitor.active]
        guard !windows.isEmpty else { return nil }
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
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        hasShadow = false
        isOpaque = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        appearance = MenuBarChrome.appearance
        backgroundColor = .clear
        alphaValue = 0
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
        let inset = FocusBorderLayout.width
        let inner = bounds.insetBy(dx: inset, dy: inset)
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
