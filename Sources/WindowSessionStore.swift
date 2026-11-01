import AppKit
import Foundation

package struct SessionWindowRecord: Codable, Equatable, Sendable {
    package var bundleID: String
    package var title: String
    package var displayID: UInt32
    package var workspace: Int
    package var floating: Bool
    package var floatingFrame: [Double]?

    package init(
        bundleID: String,
        title: String,
        displayID: UInt32,
        workspace: Int,
        floating: Bool,
        floatingFrame: CGRect? = nil
    ) {
        self.bundleID = bundleID
        self.title = title
        self.displayID = displayID
        self.workspace = workspace
        self.floating = floating
        if let floatingFrame {
            self.floatingFrame = [
                floatingFrame.origin.x, floatingFrame.origin.y, floatingFrame.width, floatingFrame.height,
            ]
        } else {
            self.floatingFrame = nil
        }
    }

    package var frame: CGRect? {
        guard let floatingFrame, floatingFrame.count == 4 else { return nil }
        return CGRect(
            x: floatingFrame[0], y: floatingFrame[1], width: floatingFrame[2], height: floatingFrame[3])
    }
}

package struct WindowSessionSnapshot: Codable, Equatable, Sendable {
    package var windows: [SessionWindowRecord]
    package var activeByDisplay: [String: Int]

    package init(windows: [SessionWindowRecord] = [], activeByDisplay: [String: Int] = [:]) {
        self.windows = windows
        self.activeByDisplay = activeByDisplay
    }
}

package enum WindowSessionMatching {
    package static func take(
        from records: inout [SessionWindowRecord],
        bundleID: String,
        title: String,
        displayID: CGDirectDisplayID,
        workspaceCount: Int
    ) -> SessionWindowRecord? {
        if let index = records.firstIndex(where: {
            $0.bundleID == bundleID && $0.title == title && $0.displayID == displayID
                && WorkspaceBounds.isValidIndex($0.workspace, count: workspaceCount)
        }) {
            return records.remove(at: index)
        }
        if let index = records.firstIndex(where: {
            $0.bundleID == bundleID && $0.title == title
                && WorkspaceBounds.isValidIndex($0.workspace, count: workspaceCount)
        }) {
            return records.remove(at: index)
        }
        return nil
    }
}

@MainActor
package final class WindowSessionStore {
    package static let shared = WindowSessionStore()

    package static var path: String {
        NSString("~/.config/parket/session.json").expandingTildeInPath
    }

    private let saveDebounce = Debounce()
    private var restoring: [SessionWindowRecord] = []
    private var restoringActive: [String: Int] = [:]
    private var isRestoring = false

    private init() {}

    package func beginRestore() {
        let snapshot = Self.load()
        restoring = snapshot.windows
        restoringActive = snapshot.activeByDisplay
        isRestoring = true
    }

    func take(
        pid: pid_t,
        title: String?,
        displayID: CGDirectDisplayID,
        workspaceCount: Int
    ) -> SessionWindowRecord? {
        guard isRestoring else { return nil }
        return WindowSessionMatching.take(
            from: &restoring,
            bundleID: Self.bundleID(for: pid),
            title: Self.normalizedTitle(title),
            displayID: displayID,
            workspaceCount: workspaceCount
        )
    }

    package func activeWorkspace(displayID: CGDirectDisplayID, count: Int) -> Int? {
        guard isRestoring,
            let value = restoringActive[String(displayID)],
            WorkspaceBounds.isValidIndex(value, count: count)
        else { return nil }
        return value
    }

    package func endRestore() {
        restoring = []
        restoringActive = [:]
        isRestoring = false
    }

    package func scheduleSave(from monitors: [Monitor]) {
        saveDebounce.schedule(after: 0.4) { [self] in
            saveNow(from: monitors)
        }
    }

    package func saveNow(from monitors: [Monitor]) {
        saveDebounce.cancel()
        let snapshot = Self.capture(from: monitors)
        Self.write(snapshot)
    }

    static func capture(from monitors: [Monitor]) -> WindowSessionSnapshot {
        var windows: [SessionWindowRecord] = []
        var activeByDisplay: [String: Int] = [:]
        for monitor in monitors {
            activeByDisplay[String(monitor.displayID)] = monitor.active
            for workspace in monitor.workspaces.indices {
                for window in monitor.workspaces[workspace] {
                    let floating = monitor.isFloating(window)
                    windows.append(
                        SessionWindowRecord(
                            bundleID: bundleID(for: window.pid),
                            title: normalizedTitle(window.title()),
                            displayID: monitor.displayID,
                            workspace: workspace,
                            floating: floating,
                            floatingFrame: floating ? monitor.floatingFrame(for: window) : nil
                        ))
                }
            }
        }
        return WindowSessionSnapshot(windows: windows, activeByDisplay: activeByDisplay)
    }

    package static func bundleID(for pid: pid_t) -> String {
        let app = NSRunningApplication(processIdentifier: pid)
        if let bundle = app?.bundleIdentifier, !bundle.isEmpty { return bundle }
        if let name = app?.localizedName, !name.isEmpty { return name }
        return "pid:\(pid)"
    }

    package static func normalizedTitle(_ title: String?) -> String {
        (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func load() -> WindowSessionSnapshot {
        guard let data = FileManager.default.contents(atPath: path) else {
            return WindowSessionSnapshot()
        }
        return (try? JSONDecoder().decode(WindowSessionSnapshot.self, from: data))
            ?? WindowSessionSnapshot()
    }

    private static func write(_ snapshot: WindowSessionSnapshot) {
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
