import AppKit

enum MenuBarChrome {
    static var color: NSColor {
        NSColor(name: "parket.menuBarFill") { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.118, green: 0.118, blue: 0.118, alpha: 1)
                : NSColor(srgbRed: 0.965, green: 0.965, blue: 0.965, alpha: 1)
        }
    }
}

@MainActor
package final class DesktopBackground {
    package static let shared = DesktopBackground()

    private var appearanceObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    private init() {}

    package func start() {
        if appearanceObserver == nil {
            appearanceObserver = DistributedNotificationCenter.default.addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
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
        let color = MenuBarChrome.color
        guard let url = writeImage(color) else { return }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .allowClipping: true,
            .fillColor: color,
        ]
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
    }

    private func writeImage(_ color: NSColor) -> URL? {
        let directory = Config.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("desktop.png")
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
        (color.usingColorSpace(.deviceRGB) ?? color).setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        try? png.write(to: url)
        return url
    }
}
