import AppKit

@MainActor
package final class MouseFocus {
    package static let shared = MouseFocus()

    private static let settleDelay: TimeInterval = 0.05

    private var eventMonitor: Any?
    private let checkDebounce = Debounce()
    private var lastHovered: TrackedWindow?

    private init() {}

    package func apply(enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    package func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        checkDebounce.cancel()
        lastHovered = nil
    }

    private func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
            MainActor.assumeIsolated {
                MouseFocus.shared.scheduleCheck()
            }
        }
    }

    private func scheduleCheck() {
        checkDebounce.schedule(after: Self.settleDelay) {
            MouseFocus.shared.focusWindowUnderPointer()
        }
    }

    private func focusWindowUnderPointer() {
        guard NSEvent.pressedMouseButtons == 0, let point = CGEvent(source: nil)?.location else { return }
        guard let target = WorkspaceManager.shared.tiledWindow(at: point) else {
            lastHovered = nil
            return
        }
        guard target != lastHovered else { return }
        if let top = WindowManager.topWindow(at: point),
            WorkspaceManager.shared.visibleWindow(pid: top.pid, element: top.element) == nil
        {
            return
        }
        lastHovered = target
        guard WindowManager.focusedWindow() != target else { return }
        target.focus()
    }
}
