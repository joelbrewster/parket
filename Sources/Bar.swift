import AppKit

package enum BarLayout {
    package static let height: CGFloat = 28
    package static let gap: CGFloat = 0
    package static var topPad: CGFloat { 2 }
    package static var reservedTop: CGFloat { height + topPad + gap }

    package static func overlayHeight(menuBar: CGFloat) -> CGFloat {
        max(menuBar, height) + topPad
    }

    package static func windowFrame(for screen: NSScreen) -> CGRect {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let height = overlayHeight(menuBar: frame.maxY - visible.maxY)
        return CGRect(
            x: frame.origin.x,
            y: frame.maxY - height,
            width: frame.width,
            height: height
        )
    }

    package static func tileFrame(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        gap: CGFloat = BarLayout.gap
    ) -> CGRect {
        let top = screenFrame.minY + overlayHeight(menuBar: visibleFrame.minY - screenFrame.minY) + gap
        return CGRect(
            x: visibleFrame.minX,
            y: top,
            width: visibleFrame.width,
            height: max(0, visibleFrame.maxY - top)
        )
    }
}

@MainActor
package final class Bar {
    package static let shared = Bar()

    private var started = false
    private var panels: [CGDirectDisplayID: BarPanel] = [:]
    private var clockTimer: Timer?
    private let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEE d MMM h:mm"
        return formatter
    }()

    private init() {}

    package func start() {
        started = true
        if clockTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { _ in
                MainActor.assumeIsolated {
                    Bar.shared.refreshClock()
                }
            }
            timer.tolerance = 0.25
            RunLoop.main.add(timer, forMode: .common)
            clockTimer = timer
        }
        Weather.shared.start()
        Battery.shared.start()
        NowPlaying.shared.start()
        DesktopBackground.shared.start()
        DesktopOverlay.shared.start()
        sync(screens: NSScreen.screens)
    }

    package func sync(screens: [NSScreen]) {
        guard started else { return }
        guard Config.shared.bar else {
            for id in panels.keys {
                panels.removeValue(forKey: id)?.close()
            }
            return
        }
        let ids = Set(screens.map { WindowManager.displayID(for: $0) })
        for id in panels.keys where !ids.contains(id) {
            panels.removeValue(forKey: id)?.close()
        }
        for screen in screens {
            let id = WindowManager.displayID(for: screen)
            let panel = panels[id] ?? BarPanel(displayID: id)
            panel.place(on: screen)
            panel.orderFrontRegardless()
            panels[id] = panel
        }
        update()
    }

    package func applyAppearance() {
        let appearance = MenuBarChrome.appearance
        let color = MenuBarChrome.color
        for panel in panels.values {
            panel.appearance = appearance
            panel.backgroundColor = color
            panel.barView.needsDisplay = true
        }
    }

    package func update() {
        let status = statusItems()
        let ws = WorkspaceManager.shared
        let focusedID = ws.monitors.isEmpty ? nil : ws.focusedMonitor.displayID
        for (id, panel) in panels {
            let monitor = ws.monitors.first { $0.displayID == id }
            panel.barView.update(
                tags: tags(for: monitor),
                layout: layout(for: monitor),
                windowCount: windowCount(for: monitor),
                title: title(for: monitor),
                titleHighlighted: monitor?.displayID == focusedID,
                floating: monitor?.focusedWindowIsFloating == true,
                status: status
            )
        }
    }

    private func refreshClock() {
        let status = statusItems()
        for panel in panels.values {
            panel.barView.updateStatus(status)
        }
    }

    private func statusItems() -> BarStatus {
        BarStatus(
            music: NowPlaying.shared.text,
            battery: Battery.shared.text,
            weather: Weather.shared.text,
            clock: clockFormatter.string(from: Date())
        )
    }

    private func tags(for monitor: Monitor?) -> [BarTag] {
        let count = Config.shared.workspaceCount
        guard let monitor else {
            return (0..<count).map {
                BarTag(number: $0 + 1, label: WorkspaceNamer.shared.label(for: $0), active: $0 == 0, occupied: false)
            }
        }
        return (0..<count).map { index in
            BarTag(
                number: index + 1,
                label: WorkspaceNamer.shared.label(for: index),
                active: index == monitor.active,
                occupied: monitor.workspaces.indices.contains(index) && !monitor.workspaces[index].isEmpty
            )
        }
    }

    private func layout(for monitor: Monitor?) -> Layout {
        guard let monitor, monitor.layouts.indices.contains(monitor.active) else { return .tile }
        return monitor.layouts[monitor.active]
    }

    private func windowCount(for monitor: Monitor?) -> Int {
        guard let monitor, monitor.workspaces.indices.contains(monitor.active) else { return 0 }
        return monitor.workspaces[monitor.active].count
    }

    private func title(for monitor: Monitor?) -> String {
        guard let monitor, monitor.workspaces.indices.contains(monitor.active) else {
            return NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        }
        let windows = monitor.workspaces[monitor.active]
        if let focused = WindowManager.focusedWindow(), windows.contains(where: { $0 == focused }) {
            return displayName(for: focused)
        }
        let focusedIndex =
            monitor.focusedIndices.indices.contains(monitor.active)
            ? monitor.focusedIndices[monitor.active]
            : 0
        if windows.indices.contains(focusedIndex) {
            return displayName(for: windows[focusedIndex])
        }
        return windows.first.map(displayName) ?? ""
    }

    private func displayName(for window: TrackedWindow) -> String {
        let title = window.title()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty { return title }
        return NSRunningApplication(processIdentifier: window.pid)?.localizedName ?? ""
    }
}

private struct BarTag: Equatable {
    let number: Int
    let label: String
    let active: Bool
    let occupied: Bool
}

private final class BarPanel: NSPanel {
    let displayID: CGDirectDisplayID
    let barView = BarContentView()

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
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
        isOpaque = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        backgroundColor = MenuBarChrome.color
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        barView.displayID = displayID
        contentView = barView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(on screen: NSScreen) {
        setFrame(BarLayout.windowFrame(for: screen), display: true)
    }
}

private struct BarStatus {
    var music = ""
    var battery = ""
    var weather = ""
    var clock = ""
}

private enum BarHit {
    case tag(Int)
    case layout
    case music
    case battery
    case weather
    case clock
}

private enum BarLaunch {
    static func open(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

private final class BarContentView: NSView {
    var displayID: CGDirectDisplayID = 0
    private var tags: [BarTag] = []
    private var layout: Layout = .initial
    private var windowCount = 0
    private var titleText = ""
    private var titleHighlighted = false
    private var floating = false
    private var status = BarStatus()
    private var hits: [(BarHit, NSRect)] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func update(
        tags: [BarTag],
        layout: Layout,
        windowCount: Int,
        title: String,
        titleHighlighted: Bool,
        floating: Bool,
        status: BarStatus
    ) {
        self.tags = tags
        self.layout = layout
        self.windowCount = windowCount
        titleText = title
        self.titleHighlighted = titleHighlighted
        self.floating = floating
        self.status = status
        needsDisplay = true
    }

    func updateStatus(_ status: BarStatus) {
        self.status = status
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        MenuBarChrome.color.setFill()
        bounds.fill()
        let font = Config.shared.barFont.nsFont()
        let margin = FocusBorderLayout.width
        let topPad = BarLayout.topPad
        let contentHeight = max(0, bounds.height - topPad)
        let capHeight = font.capHeight > 0 ? font.capHeight : font.ascender
        let textHeight = ceil(font.ascender - font.descender)
        let textY = topPad + contentHeight / 2 - font.ascender + capHeight / 2
        var x: CGFloat = margin
        hits = []

        let titleStyle = Config.shared.barHighlight
        let tagStyle = Config.shared.barTagHighlight
        let tagSide = contentHeight
        let markSide: CGFloat = 5
        for (index, tag) in tags.enumerated() {
            let width = max(tagSide, ceil(textSize(tag.label, font: font).width) + 10)
            let rect = NSRect(x: x, y: topPad, width: width, height: tagSide)
            if tag.active, titleHighlighted, tagStyle != .text {
                paintAccent(rect.insetBy(dx: 0, dy: margin), style: tagStyle)
            }
            drawText(
                tag.label,
                in: rect,
                font: font,
                color: tagColor(tag, style: tagStyle, focused: titleHighlighted),
                textY: textY,
                textHeight: textHeight
            )
            if tag.occupied {
                let mark = NSRect(x: rect.minX + 3, y: topPad + 3, width: markSide, height: markSide)
                tagColor(tag, style: tagStyle, focused: titleHighlighted).setFill()
                mark.fill()
            }
            hits.append((.tag(index), rect))
            x += width
        }

        let symbol = floating ? "><>" : (layout == .monocle ? "[M]" : "[]=")
        let layoutRect = NSRect(x: x, y: topPad, width: cellWidth(symbol, font: font), height: contentHeight)
        drawText(symbol, in: layoutRect, font: font, color: .labelColor, textY: textY, textHeight: textHeight)
        hits.append((.layout, layoutRect))
        x = layoutRect.maxX

        if windowCount > 0 {
            let countRect = NSRect(
                x: x, y: topPad, width: cellWidth("\(windowCount)", font: font), height: contentHeight)
            drawText(
                "\(windowCount)", in: countRect, font: font, color: .secondaryLabelColor, textY: textY,
                textHeight: textHeight)
            x = countRect.maxX
        }

        var right = bounds.maxX - margin
        let statusItems: [(String, BarHit)] = [
            (status.clock, .clock),
            (status.weather, .weather),
            (status.battery, .battery),
            (status.music, .music),
        ]
        for (text, hit) in statusItems {
            guard !text.isEmpty else { continue }
            let width = ceil(textSize(text, font: font).width) + 16
            right -= width
            let rect = NSRect(x: right, y: topPad, width: width, height: contentHeight)
            let color: NSColor = {
                if case .clock = hit { return .labelColor }
                return .secondaryLabelColor
            }()
            drawText(text, in: rect, font: font, color: color, textY: textY, textHeight: textHeight)
            hits.append((hit, rect))
        }

        let titleMargin: CGFloat = 8
        let titlePadding: CGFloat = 10
        let titleSlot = max(0, right - x)
        let titleRect = NSRect(
            x: x + titleMargin,
            y: topPad,
            width: max(0, titleSlot - titleMargin * 2),
            height: contentHeight
        )
        if titleHighlighted && !titleText.isEmpty, titleStyle != .text {
            paintAccent(titleRect.insetBy(dx: 0, dy: margin), style: titleStyle)
        }
        drawText(
            titleText,
            in: titleRect,
            font: font,
            color: titleColor(highlighted: titleHighlighted && !titleText.isEmpty, style: titleStyle),
            truncate: true,
            padding: titlePadding,
            textY: textY,
            textHeight: textHeight
        )
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            StatusBar.shared.popUpMenu(with: event, in: self)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = hits.first(where: { $0.1.contains(point) })?.0 else { return }
        switch hit {
        case .tag(let index):
            WorkspaceManager.shared.switchTo(index, displayID: displayID)
        case .layout:
            WorkspaceManager.shared.toggleLayout(displayID: displayID)
        case .music:
            BarLaunch.open(bundleID: "com.apple.Music")
        case .battery:
            let panes = [
                "x-apple.systempreferences:com.apple.Battery-Settings.extension",
                "x-apple.systempreferences:com.apple.preference.battery",
            ]
            for pane in panes {
                if let url = URL(string: pane), NSWorkspace.shared.open(url) { return }
            }
            BarLaunch.open(bundleID: "com.apple.systempreferences")
        case .weather:
            BarLaunch.open(bundleID: "com.apple.weather")
        case .clock:
            BarLaunch.open(bundleID: "com.apple.iCal")
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        StatusBar.shared.popUpMenu(with: event, in: self)
    }

    private func tagColor(_ tag: BarTag, style: BarHighlight, focused: Bool) -> NSColor {
        guard tag.active, focused else {
            return tag.occupied ? .labelColor : .tertiaryLabelColor
        }
        switch style {
        case .fill: return .white
        case .outline: return .labelColor
        case .text: return MenuBarChrome.accent
        }
    }

    private func titleColor(highlighted: Bool, style: BarHighlight) -> NSColor {
        guard highlighted else { return .labelColor }
        switch style {
        case .fill: return .white
        case .outline: return .labelColor
        case .text: return MenuBarChrome.accent
        }
    }

    private func paintAccent(_ rect: NSRect, style: BarHighlight) {
        let width = Config.shared.borderWidth
        let inner =
            style == .outline
            ? rect.insetBy(dx: width / 2, dy: width / 2)
            : rect
        let radius = min(
            Config.shared.borderRadius,
            max(0, inner.width / 2),
            max(0, inner.height / 2)
        )
        let path = NSBezierPath(roundedRect: inner, xRadius: radius, yRadius: radius)
        switch style {
        case .fill:
            MenuBarChrome.accent.setFill()
            path.fill()
        case .outline:
            MenuBarChrome.accent.setStroke()
            path.lineWidth = width
            path.stroke()
        case .text:
            break
        }
    }

    private func cellWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil(textSize(text, font: font).width) + 16
    }

    private func textSize(_ text: String, font: NSFont) -> NSSize {
        NSAttributedString(string: text, attributes: [.font: font]).size()
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        truncate: Bool = false,
        padding: CGFloat = 8,
        textY: CGFloat,
        textHeight: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = truncate ? .byTruncatingTail : .byClipping
        if truncate { paragraph.alignment = .left }
        let inset = truncate ? padding : 0
        let attr = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
        let textRect = NSRect(
            x: rect.minX + inset,
            y: textY,
            width: max(0, rect.width - inset * 2),
            height: textHeight
        )
        attr.draw(with: textRect, options: [.usesLineFragmentOrigin])
    }
}
