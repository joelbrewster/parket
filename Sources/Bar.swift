import AppKit

package enum BarLayout {
    package static let height: CGFloat = 28
    package static let gap: CGFloat = 0
    package static var reservedTop: CGFloat { height + gap }

    package static func windowFrame(for screen: NSScreen) -> CGRect {
        let frame = screen.frame
        return CGRect(
            x: frame.origin.x,
            y: frame.maxY - height,
            width: frame.width,
            height: height
        )
    }

    package static func tileFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let top = screenFrame.minY + reservedTop
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
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
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
        sync(screens: NSScreen.screens)
    }

    package func sync(screens: [NSScreen]) {
        guard started else { return }
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

    package func update() {
        let clock = clockFormatter.string(from: Date())
        let ws = WorkspaceManager.shared
        for (id, panel) in panels {
            let monitor = ws.monitors.first { $0.displayID == id }
            panel.barView.update(
                tags: tags(for: monitor),
                layout: layout(for: monitor),
                windowCount: windowCount(for: monitor),
                title: title(for: monitor),
                clock: clock
            )
        }
    }

    private func refreshClock() {
        let clock = clockFormatter.string(from: Date())
        for panel in panels.values {
            panel.barView.updateClock(clock)
        }
    }

    private func tags(for monitor: Monitor?) -> [BarTag] {
        let count = Config.shared.workspaceCount
        guard let monitor else {
            return (0..<count).map { BarTag(number: $0 + 1, active: $0 == 0, occupied: false) }
        }
        return (0..<count).map { index in
            BarTag(
                number: index + 1,
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
        isOpaque = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        animationBehavior = .none
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        let root = NSView()
        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.isEmphasized = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        barView.translatesAutoresizingMaskIntoConstraints = false
        barView.displayID = displayID
        root.addSubview(effect)
        root.addSubview(barView)
        contentView = root
        if let root = contentView {
            NSLayoutConstraint.activate([
                effect.leadingAnchor.constraint(equalTo: root.leadingAnchor),
                effect.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                effect.topAnchor.constraint(equalTo: root.topAnchor),
                effect.bottomAnchor.constraint(equalTo: root.bottomAnchor),
                barView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
                barView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                barView.topAnchor.constraint(equalTo: root.topAnchor),
                barView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            ])
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(on screen: NSScreen) {
        setFrame(BarLayout.windowFrame(for: screen), display: true)
    }
}

private enum BarHit {
    case tag(Int)
    case layout
}

private final class BarContentView: NSView {
    var displayID: CGDirectDisplayID = 0
    private var tags: [BarTag] = []
    private var layout: Layout = .tile
    private var windowCount = 0
    private var titleText = ""
    private var clock = ""
    private var hits: [(BarHit, NSRect)] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func update(tags: [BarTag], layout: Layout, windowCount: Int, title: String, clock: String) {
        self.tags = tags
        self.layout = layout
        self.windowCount = windowCount
        titleText = title
        self.clock = clock
        needsDisplay = true
    }

    func updateClock(_ clock: String) {
        self.clock = clock
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.menuBarFont(ofSize: 0)
        let mono = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .medium)
        var x: CGFloat = 0
        hits = []

        let tagSide = bounds.height
        let markSide: CGFloat = 5
        for (index, tag) in tags.enumerated() {
            let rect = NSRect(x: x, y: 0, width: tagSide, height: tagSide)
            if tag.active {
                NSColor.controlAccentColor.setFill()
                rect.fill()
            }
            drawText(
                "\(tag.number)",
                in: rect,
                font: font,
                color: tag.active ? .white : (tag.occupied ? .labelColor : .tertiaryLabelColor)
            )
            if tag.occupied && !tag.active {
                let mark = NSRect(x: rect.minX + 3, y: 3, width: markSide, height: markSide)
                NSColor.labelColor.setFill()
                mark.fill()
            }
            hits.append((.tag(index), rect))
            x += tagSide
        }

        let symbol = layout == .monocle ? "[M]" : "[]="
        let layoutRect = NSRect(x: x, y: 0, width: cellWidth(symbol, font: mono), height: bounds.height)
        drawText(symbol, in: layoutRect, font: mono, color: .labelColor)
        hits.append((.layout, layoutRect))
        x = layoutRect.maxX

        if windowCount > 0 {
            let countRect = NSRect(x: x, y: 0, width: cellWidth("\(windowCount)", font: font), height: bounds.height)
            drawText("\(windowCount)", in: countRect, font: font, color: .secondaryLabelColor)
            x = countRect.maxX
        }

        let clockWidth = textSize(clock, font: font).width + 16
        let clockRect = NSRect(
            x: bounds.maxX - clockWidth,
            y: 0,
            width: clockWidth,
            height: bounds.height
        )
        drawText(clock, in: clockRect, font: font, color: .secondaryLabelColor)

        let titleRect = NSRect(x: x, y: 0, width: max(0, clockRect.minX - x), height: bounds.height)
        drawText(titleText, in: titleRect, font: font, color: .labelColor, truncate: true)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = hits.first(where: { $0.1.contains(point) })?.0 else { return }
        switch hit {
        case .tag(let index):
            WorkspaceManager.shared.switchTo(index, displayID: displayID)
        case .layout:
            WorkspaceManager.shared.toggleLayout(displayID: displayID)
        }
    }

    private func cellWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil(textSize(text, font: font).width) + 16
    }

    private func textSize(_ text: String, font: NSFont) -> NSSize {
        NSAttributedString(string: text, attributes: [.font: font]).size()
    }

    private func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, truncate: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = truncate ? .byTruncatingTail : .byClipping
        if truncate { paragraph.alignment = .left }
        let inset = truncate ? 8 : 0
        let drawRect = NSRect(
            x: rect.minX + CGFloat(inset),
            y: rect.minY,
            width: max(0, rect.width - CGFloat(inset) * (truncate ? 1 : 0)),
            height: rect.height
        )
        let attr = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
        let size = attr.size()
        let textRect = NSRect(
            x: drawRect.minX,
            y: drawRect.minY + (drawRect.height - size.height) / 2,
            width: drawRect.width,
            height: size.height
        )
        attr.draw(with: textRect, options: [.usesLineFragmentOrigin])
    }
}
