import AppKit

@MainActor
package final class NowPlaying: NSObject {
    package static let shared = NowPlaying()

    package private(set) var text = ""

    private var timer: Timer?

    private override init() {
        super.init()
    }

    package func start() {
        guard timer == nil else { return }
        let center = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo"] {
            center.addObserver(
                self,
                selector: #selector(playerInfo(_:)),
                name: Notification.Name(name),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        refresh()
        let timer = Timer(timeInterval: 5, repeats: true) { _ in
            MainActor.assumeIsolated {
                NowPlaying.shared.refresh()
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func playerInfo(_ note: Notification) {
        let info = note.userInfo
        apply(
            state: info?["Player State"] as? String,
            name: info?["Name"] as? String,
            artist: info?["Artist"] as? String
        )
    }

    @objc private func appTerminated(_ note: Notification) {
        let bundle = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
            .bundleIdentifier
        guard bundle == "com.apple.Music" else { return }
        setText("")
    }

    private func apply(state: String?, name: String?, artist: String?) {
        let status = state?.lowercased() ?? ""
        if status == "stopped" {
            refresh()
            return
        }
        guard status == "playing" || status == "paused" else { return }
        let track = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let by = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if track.isEmpty { return }
        setText(by.isEmpty ? track : "\(by) – \(track)")
    }

    private func refresh() {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
        guard running else {
            setText("")
            return
        }
        let script = NSAppleScript(
            source: """
                tell application "Music"
                    set st to player state as string
                    if st is "stopped" then return "stop"
                    if st is "playing" or st is "paused" then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        if trackArtist is not "" then
                            return "track:" & trackArtist & " – " & trackName
                        end if
                        return "track:" & trackName
                    end if
                    return "keep"
                end tell
                """
        )
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error), error == nil else { return }
        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value == "stop" {
            setText("")
        } else if value.hasPrefix("track:") {
            setText(String(value.dropFirst(6)))
        }
    }

    private func setText(_ next: String) {
        let clipped = clip(next)
        guard clipped != text else { return }
        text = clipped
        Bar.shared.update()
    }

    private func clip(_ value: String) -> String {
        guard value.count > 36 else { return value }
        return String(value.prefix(35)) + "…"
    }
}
