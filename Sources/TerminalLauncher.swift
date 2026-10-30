import AppKit

@MainActor
enum TerminalLauncher {
    static func spawn() {
        let app = configuredApp() ?? defaultApp()
        let path = app.path
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", "-a", path]
            try? process.run()
        }
    }

    static func installedNames() -> [String] {
        ["Ghostty", "Terminal", "iTerm", "Kitty", "Alacritty", "Warp", "WezTerm"].filter(exists)
    }

    private static func exists(_ name: String) -> Bool {
        let appName = name.hasSuffix(".app") ? name : "\(name).app"
        for folder in ["/Applications", NSHomeDirectory() + "/Applications", "/System/Applications/Utilities"] {
            if FileManager.default.fileExists(atPath: "\(folder)/\(appName)") { return true }
        }
        return false
    }

    private static func configuredApp() -> URL? {
        let name = Config.shared.terminal
        guard !name.isEmpty else { return nil }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return url
        }
        let appName = name.hasSuffix(".app") ? name : "\(name).app"
        for folder in ["/Applications", NSHomeDirectory() + "/Applications"] {
            let path = "\(folder)/\(appName)"
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private static func defaultApp() -> URL {
        for value in ["x-man-page://", "ssh://"] {
            if let url = URL(string: value),
                let app = NSWorkspace.shared.urlForApplication(toOpen: url),
                isTerminal(app)
            {
                return app
            }
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
            ?? URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    }

    private static func isTerminal(_ app: URL) -> Bool {
        let id = Bundle(url: app)?.bundleIdentifier?.lowercased() ?? ""
        if id.isEmpty { return true }
        return !id.contains("safari") && !id.contains("chrome") && !id.contains("firefox")
            && !id.contains("browser")
    }
}
