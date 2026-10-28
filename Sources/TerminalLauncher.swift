import AppKit

@MainActor
enum TerminalLauncher {
    static func spawn() {
        let app = defaultApp()
        let path = app.path
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", "-a", path]
            try? process.run()
        }
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
