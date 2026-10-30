import AppKit

@MainActor
package final class WorkspaceNamer {
    package static let shared = WorkspaceNamer()

    private static let maxLength = 12

    private var index: Int?
    private var draft = ""
    private var timeout: DispatchWorkItem?

    private init() {}

    package func label(for workspace: Int) -> String {
        let number = workspace + 1
        if Self.isCapturing(), index == workspace {
            return draft.isEmpty ? "\(number)-" : "\(number)-\(draft)"
        }
        if let name = Config.shared.workspaceNames[workspace], !name.isEmpty {
            return "\(number)-\(name)"
        }
        return "\(number)"
    }

    package func begin() {
        guard !WorkspaceManager.shared.monitors.isEmpty else { return }
        if Self.isCapturing() {
            cancel()
            return
        }
        index = WorkspaceManager.shared.focusedMonitor.active
        draft = ""
        Self.setCapturing(true)
        Bar.shared.update()
        pingTimeout()
    }

    package func cancel() {
        timeout?.cancel()
        timeout = nil
        index = nil
        draft = ""
        Self.setCapturing(false)
        Bar.shared.update()
    }

    nonisolated static func isCapturing() -> Bool {
        RenameCapture.lock.lock()
        defer { RenameCapture.lock.unlock() }
        return RenameCapture.on
    }

    nonisolated static func consume(type: CGEventType, event: CGEvent) -> Bool {
        guard isCapturing() else { return false }
        if type == .keyUp { return true }
        guard type == .keyDown else { return false }
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
        let stroke = KeyStroke(
            key: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            text: String(utf16CodeUnits: chars, count: max(length, 0)),
            option: event.flags.contains(.maskAlternate),
            control: event.flags.contains(.maskControl),
            command: event.flags.contains(.maskCommand)
        )
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                WorkspaceNamer.shared.apply(stroke)
            }
        }
        return true
    }

    private func apply(_ stroke: KeyStroke) {
        guard Self.isCapturing() else { return }
        if stroke.command || stroke.control {
            return
        }
        if stroke.option {
            if stroke.key == Key.n { cancel() }
            return
        }
        switch stroke.key {
        case Key.return:
            commit()
        case Key.escape:
            cancel()
        case Key.delete:
            if !draft.isEmpty { draft.removeLast() }
            Bar.shared.update()
            pingTimeout()
        default:
            let next = sanitize(stroke.text)
            guard !next.isEmpty, draft.count + next.count <= Self.maxLength else { return }
            draft += next
            Bar.shared.update()
            pingTimeout()
        }
    }

    private func commit() {
        guard let index else {
            cancel()
            return
        }
        Config.setWorkspaceName(index, draft)
        timeout?.cancel()
        timeout = nil
        self.index = nil
        draft = ""
        Self.setCapturing(false)
        Bar.shared.update()
    }

    private func pingTimeout() {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.cancel()
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func sanitize(_ text: String) -> String {
        text.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func setCapturing(_ value: Bool) {
        RenameCapture.lock.lock()
        RenameCapture.on = value
        RenameCapture.lock.unlock()
    }
}

private enum RenameCapture {
    static let lock = NSLock()
    nonisolated(unsafe) static var on = false
}

private struct KeyStroke {
    let key: UInt16
    let text: String
    let option: Bool
    let control: Bool
    let command: Bool
}
