import AppKit

enum MenuBarChrome {
    static var isDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    static var appearance: NSAppearance {
        NSAppearance(named: isDark ? .darkAqua : .aqua)!
    }

    static var color: NSColor {
        isDark
            ? NSColor(srgbRed: 0.118, green: 0.118, blue: 0.118, alpha: 1)
            : NSColor(srgbRed: 0.965, green: 0.965, blue: 0.965, alpha: 1)
    }

    static var accent: NSColor {
        opaque(highlight() ?? .systemBlue)
    }

    private static func highlight() -> NSColor? {
        guard let value = highlightPreference() else { return nil }
        let parts = value.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.count >= 4 {
            let name = parts[3].lowercased()
            if name != "other", let color = themeAccent(named: name) {
                return color
            }
        }
        if parts.count >= 3,
            let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2])
        {
            if parts.count < 4 || parts[3].lowercased() != "other",
                let snapped = snapThemeAccent(r: r, g: g, b: b)
            {
                return snapped
            }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        }
        return nil
    }

    private static func highlightPreference() -> String? {
        let key = "AppleHighlightColor"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        if let value = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[key] as? String,
            !value.isEmpty
        {
            return value
        }
        if let value = CFPreferencesCopyAppValue(key as CFString, kCFPreferencesAnyApplication) as? String,
            !value.isEmpty
        {
            return value
        }
        return nil
    }

    private static func snapThemeAccent(r: Double, g: Double, b: Double) -> NSColor? {
        let swatches: [(Double, Double, Double, NSColor)] = [
            (0.000, 0.431, 0.863, .systemBlue),
            (0.000, 0.500, 1.000, .systemBlue),
            (0.557, 0.271, 0.678, .systemPurple),
            (1.000, 0.412, 0.706, .systemPink),
            (1.000, 0.388, 0.314, .systemRed),
            (1.000, 0.584, 0.000, .systemOrange),
            (1.000, 0.875, 0.569, .systemYellow),
            (0.753, 0.965, 0.678, .systemGreen),
            (0.765, 0.977, 0.569, .systemGreen),
            (0.557, 0.557, 0.576, .systemGray),
        ]
        var best: (Double, NSColor)?
        for swatch in swatches {
            let distance =
                (r - swatch.0) * (r - swatch.0)
                + (g - swatch.1) * (g - swatch.1)
                + (b - swatch.2) * (b - swatch.2)
            if best == nil || distance < best!.0 {
                best = (distance, swatch.3)
            }
        }
        guard let best, best.0 <= 0.08 else { return nil }
        return best.1
    }

    private static func themeAccent(named name: String) -> NSColor? {
        switch name {
        case "blue": return .systemBlue
        case "purple": return .systemPurple
        case "pink": return .systemPink
        case "red": return .systemRed
        case "orange": return .systemOrange
        case "yellow", "gold": return .systemYellow
        case "green": return .systemGreen
        case "graphite", "gray", "grey": return .systemGray
        default: return nil
        }
    }

    private static func opaque(_ color: NSColor) -> NSColor {
        var result = color
        appearance.performAsCurrentDrawingAppearance {
            if let rgb = color.usingColorSpace(.sRGB) {
                result = NSColor(
                    srgbRed: rgb.redComponent,
                    green: rgb.greenComponent,
                    blue: rgb.blueComponent,
                    alpha: 1
                )
            }
        }
        return result
    }
}

@MainActor
package final class DesktopBackground {
    package static let shared = DesktopBackground()

    private var appearanceObservation: NSKeyValueObservation?
    private var themeObserver: NSObjectProtocol?
    private var colorObserver: NSObjectProtocol?
    private var highlightObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    private init() {}

    package func start() {
        if appearanceObservation == nil {
            appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
                DispatchQueue.main.async {
                    DesktopBackground.shared.apply()
                }
            }
        }
        if themeObserver == nil {
            themeObserver = DistributedNotificationCenter.default.addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    DesktopBackground.shared.apply()
                }
            }
        }
        if colorObserver == nil {
            colorObserver = NotificationCenter.default.addObserver(
                forName: NSColor.systemColorsDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    DesktopBackground.shared.apply()
                }
            }
        }
        if highlightObserver == nil {
            highlightObserver = DistributedNotificationCenter.default.addObserver(
                forName: Notification.Name("AppleColorPreferencesChangedNotification"),
                object: nil,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    DesktopBackground.shared.apply()
                }
            }
        }
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    DesktopBackground.shared.apply()
                }
            }
        }
        apply()
    }

    private func apply() {
        let appearance = MenuBarChrome.appearance
        let current = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        let next = appearance.bestMatch(from: [.darkAqua, .aqua])
        if current != next {
            NSApp.appearance = appearance
        }
        Bar.shared.applyAppearance()
        FocusBorder.shared.applyAppearance()
        DesktopOverlay.shared.applyAppearance()
        DesktopOverlay.shared.sync(screens: NSScreen.screens)
        guard let url = writeImage(MenuBarChrome.color) else { return }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .allowClipping: true,
            .fillColor: MenuBarChrome.color,
        ]
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
    }

    private func writeImage(_ color: NSColor) -> URL? {
        let directory = Config.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(MenuBarChrome.isDark ? "desktop-dark.png" : "desktop-light.png")
        let size = 8
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: size,
                pixelsHigh: size,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        try? png.write(to: url)
        return url
    }
}
