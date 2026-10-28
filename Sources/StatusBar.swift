import AppKit

@MainActor
package final class StatusBar: NSObject, NSMenuDelegate {
    package static let shared = StatusBar()

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let contentView = StatusContentView()
    private var lastState: StatusState?
    private let stateSummaryItem = NSMenuItem(title: "parket", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause Tiling", action: #selector(togglePause), keyEquivalent: "p")
    private let retileItem = NSMenuItem(title: "Retile Now", action: #selector(retileNow), keyEquivalent: "t")
    private let restoreItem = NSMenuItem(
        title: "Pause and Restore Windows", action: #selector(restoreAllWindows), keyEquivalent: "")
    private let openAccessibilityItem = NSMenuItem(
        title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let recheckAccessibilityItem = NSMenuItem(
        title: "Recheck Accessibility", action: #selector(recheckPermissions), keyEquivalent: "")
    private let openConfigItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
    private let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
    private let copyDiagnosticsItem = NSMenuItem(
        title: "Copy Diagnostic Report", action: #selector(copyDiagnosticReport), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit parket", action: #selector(quit), keyEquivalent: "q")
    private let stateSeparator = NSMenuItem.separator()
    private let problemSeparator = NSMenuItem.separator()
    private let configSeparator = NSMenuItem.separator()
    private let diagnosticsSeparator = NSMenuItem.separator()
    private let quitSeparator = NSMenuItem.separator()

    private override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        buildMenu()
        installContentView()
        update()
    }

    private func buildMenu() {
        menu.delegate = self
        for item in [
            pauseItem,
            retileItem,
            restoreItem,
            openAccessibilityItem,
            recheckAccessibilityItem,
            openConfigItem,
            reloadItem,
            copyDiagnosticsItem,
            quitItem,
        ] {
            item.target = self
        }

        stateSummaryItem.isEnabled = false
        menu.addItem(stateSummaryItem)
        menu.addItem(stateSeparator)
        menu.addItem(pauseItem)
        menu.addItem(retileItem)
        menu.addItem(restoreItem)
        menu.addItem(problemSeparator)
        menu.addItem(openAccessibilityItem)
        menu.addItem(recheckAccessibilityItem)
        menu.addItem(configSeparator)
        menu.addItem(openConfigItem)
        menu.addItem(reloadItem)
        menu.addItem(diagnosticsSeparator)
        menu.addItem(copyDiagnosticsItem)
        menu.addItem(quitSeparator)
        menu.addItem(quitItem)
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if let event = NSApp.currentEvent, event.type == .leftMouseDown, !event.modifierFlags.contains(.control) {
            let point = contentView.convert(event.locationInWindow, from: nil)
            switch contentView.segment(at: point) {
            case .badge(let number, _, _):
                WorkspaceManager.shared.switchTo(number - 1)
                return
            case .layout:
                WorkspaceManager.shared.toggleLayout()
                return
            default:
                break
            }
        }
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    package func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    @objc private func openAccessibilitySettings() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
        ParketRuntime.shared.refreshPermissions(prompt: false)
    }

    @objc private func recheckPermissions() {
        ParketRuntime.shared.refreshPermissions(prompt: false)
    }

    @objc private func togglePause() {
        WorkspaceManager.shared.toggleTilingPaused()
    }

    @objc private func retileNow() {
        WorkspaceManager.shared.retileNow()
    }

    @objc private func restoreAllWindows() {
        WorkspaceManager.shared.pauseTilingAndRestoreAllWindows()
    }

    @objc private func reloadConfig() {
        ParketRuntime.shared.reloadConfig()
    }

    @objc private func openConfig() {
        Config.openConfig()
    }

    @objc private func copyDiagnosticReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ParketRuntime.shared.diagnosticReport(), forType: .string)
        copyDiagnosticsItem.title = "Diagnostic Report Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.copyDiagnosticsItem.title = "Copy Diagnostic Report"
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func update() {
        let ws = WorkspaceManager.shared
        let state = StatusState.capture(ws)
        guard state != lastState else { return }
        lastState = state
        updateMenu()

        var segments: [StatusSegment] = []
        let font = NSFont.menuBarFont(ofSize: 0)
        let fontSize = font.pointSize
        let runtime = ParketRuntime.shared

        if !runtime.permissions.isReady {
            segments.append(.symbol(name: "accessibility", accessibilityLabel: "Accessibility Missing"))
            applySegments(segments, fontSize: fontSize)
            return
        }

        if runtime.startupIssue != nil {
            segments.append(.symbol(name: "exclamationmark.triangle", accessibilityLabel: "Startup Issue"))
            applySegments(segments, fontSize: fontSize)
            return
        }

        if Hotkeys.shared.status == .degraded {
            segments.append(.symbol(name: "keyboard", accessibilityLabel: "Hotkeys Degraded"))
        }

        if ws.isTilingPaused {
            segments.append(.symbol(name: "pause.fill", accessibilityLabel: "Tiling Paused"))
        }

        guard !ws.monitors.isEmpty else {
            segments.append(.badge(number: 1, active: true, occupied: false))
            applySegments(segments, fontSize: fontSize)
            return
        }

        let monitor = ws.focusedMonitor

        if ws.monitors.count > 1 {
            let monitorNumber = ws.focusedMonitorIndex + 1
            segments.append(.monitor(number: monitorNumber))
        }

        segments.append(
            .layout(
                monitor.layouts[monitor.active],
                windowCount: monitor.workspaces[monitor.active].count,
                masterRatio: Config.shared.masterRatio
            )
        )

        for i in 0..<Config.shared.workspaceCount {
            segments.append(
                .badge(number: i + 1, active: i == monitor.active, occupied: !monitor.workspaces[i].isEmpty)
            )
        }

        applySegments(segments, fontSize: fontSize)
    }

    private func updateMenu() {
        let runtime = ParketRuntime.shared
        let permissions = runtime.permissions
        let ws = WorkspaceManager.shared

        stateSummaryItem.title = stateSummaryTitle()
        stateSummaryItem.isEnabled = false

        let showAccessibilityActions = !permissions.accessibility
        problemSeparator.isHidden = !showAccessibilityActions
        openAccessibilityItem.isHidden = !showAccessibilityActions
        recheckAccessibilityItem.isHidden = !showAccessibilityActions

        pauseItem.state = ws.isTilingPaused ? .on : .off
        pauseItem.isEnabled = runtime.isRunning
        retileItem.isEnabled = runtime.isRunning
        restoreItem.isEnabled = runtime.isRunning
        reloadItem.isEnabled = true
        openConfigItem.isEnabled = true
        copyDiagnosticsItem.isEnabled = true
    }

    private func stateSummaryTitle() -> String {
        let runtime = ParketRuntime.shared
        let ws = WorkspaceManager.shared

        if !runtime.permissions.isReady {
            return "parket: Accessibility Missing"
        }

        if runtime.startupIssue != nil {
            return "parket: Startup Issue"
        }

        var problemParts: [String] = []
        if Hotkeys.shared.status == .degraded {
            problemParts.append("Hotkeys Degraded")
        }
        if ws.isTilingPaused {
            problemParts.append("Paused")
        }
        if !problemParts.isEmpty {
            return "parket: \(problemParts.joined(separator: ", "))"
        }

        guard !ws.monitors.isEmpty else {
            return "parket: Workspace 1"
        }

        let monitor = ws.focusedMonitor
        let display = ws.monitors.count > 1 ? "Display \(ws.focusedMonitorIndex + 1), " : ""
        let layout = monitor.layouts[monitor.active] == .monocle ? "Monocle" : "Tile"
        let count = monitor.workspaces[monitor.active].count
        return "parket: \(display)Workspace \(monitor.active + 1), \(layout), \(count) \(windowWord(count))"
    }

    private func installContentView() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        contentView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            contentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
        ])
    }

    private func applySegments(_ segments: [StatusSegment], fontSize: CGFloat) {
        contentView.update(segments: segments, fontSize: fontSize)
        statusItem.length = contentView.intrinsicContentSize.width
    }
}

private let badgeColor = NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 230 / 255, green: 230 / 255, blue: 235 / 255, alpha: 1)
        : NSColor(red: 26 / 255, green: 34 / 255, blue: 37 / 255, alpha: 1)
}

private func windowWord(_ count: Int) -> String {
    count == 1 ? "window" : "windows"
}

enum TileGlyph {
    static let maxStackSlices = 3
    static let gap: CGFloat = 1

    static func rects(windowCount: Int, masterRatio: CGFloat, in area: CGRect) -> [CGRect] {
        guard windowCount > 0 else { return [] }
        guard windowCount > 1 else { return [area] }

        let masterWidth = floor(area.width * masterRatio - gap / 2)
        let master = CGRect(x: area.minX, y: area.minY, width: masterWidth, height: area.height)
        let stackX = master.maxX + gap
        let slices = min(windowCount - 1, maxStackSlices)
        let pitch = area.height + gap
        let stack = (0..<slices).map { index in
            let top = area.maxY - (pitch * CGFloat(index) / CGFloat(slices)).rounded()
            let bottom = area.maxY - (pitch * CGFloat(index + 1) / CGFloat(slices)).rounded() + gap
            return CGRect(x: stackX, y: bottom, width: area.maxX - stackX, height: top - bottom)
        }
        return [master] + stack
    }
}

private func drawCenteredText(_ text: String, in bounds: NSRect, fontSize: CGFloat, color: NSColor, ctx: CGContext) {
    let font = NSFont.systemFont(ofSize: fontSize - 1)
    let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    let line = CTLineCreateWithAttributedString(str)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    let textX = bounds.midX - lineBounds.width / 2 - lineBounds.origin.x
    let textY = bounds.midY - font.capHeight / 2
    ctx.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, ctx)
}

private enum StatusSegment: Equatable {
    case badge(number: Int, active: Bool, occupied: Bool)
    case symbol(name: String, accessibilityLabel: String)
    case monitor(number: Int)
    case layout(Layout, windowCount: Int, masterRatio: CGFloat)

    func size(fontSize: CGFloat) -> CGSize {
        switch self {
        case .badge:
            let side = fontSize + 6
            return CGSize(width: side, height: side)
        case .symbol:
            let side = fontSize + 6
            return CGSize(width: side, height: side)
        case .monitor:
            return CGSize(width: fontSize + 12, height: fontSize + 6)
        case .layout(.monocle, let windowCount, _):
            return CGSize(width: windowCount > 1 ? fontSize + 15 : fontSize + 6, height: fontSize + 6)
        case .layout(.tile, _, _):
            return CGSize(width: fontSize + 10, height: fontSize + 6)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .badge(let number, let active, let occupied):
            if active { return "Workspace \(number), Active" }
            return occupied ? "Workspace \(number)" : "Workspace \(number), Empty"
        case .symbol(_, let accessibilityLabel):
            return accessibilityLabel
        case .monitor(let number):
            return "Display \(number)"
        case .layout(let layout, let windowCount, _):
            let name = layout == .monocle ? "Monocle" : "Tile"
            return "\(name) Layout, \(windowCount) \(windowCount == 1 ? "Window" : "Windows")"
        }
    }
}

private struct StatusState: Equatable {
    let permissions: PermissionSnapshot
    let startupIssue: String?
    let runtimeRunning: Bool
    let hotkeyStatus: HotkeyStatus
    let hotkeyIssueCount: Int
    let tilingPaused: Bool
    let monitorCount: Int
    let focusedMonitorIndex: Int
    let activeWorkspace: Int
    let activeLayout: Layout
    let occupiedWorkspaces: [Bool]
    let activeWindowCount: Int
    let masterRatio: CGFloat

    @MainActor
    static func capture(_ ws: WorkspaceManager) -> StatusState {
        let runtime = ParketRuntime.shared
        guard !ws.monitors.isEmpty else {
            return StatusState(
                permissions: runtime.permissions,
                startupIssue: runtime.startupIssue,
                runtimeRunning: runtime.isRunning,
                hotkeyStatus: Hotkeys.shared.status,
                hotkeyIssueCount: Hotkeys.shared.issueCount,
                tilingPaused: ws.isTilingPaused,
                monitorCount: 0, focusedMonitorIndex: 0, activeWorkspace: 0,
                activeLayout: .tile, occupiedWorkspaces: [], activeWindowCount: 0,
                masterRatio: Config.shared.masterRatio
            )
        }
        let monitor = ws.focusedMonitor
        let occupied = (0..<Config.shared.workspaceCount).map { !monitor.workspaces[$0].isEmpty }
        return StatusState(
            permissions: runtime.permissions,
            startupIssue: runtime.startupIssue,
            runtimeRunning: runtime.isRunning,
            hotkeyStatus: Hotkeys.shared.status,
            hotkeyIssueCount: Hotkeys.shared.issueCount,
            tilingPaused: ws.isTilingPaused,
            monitorCount: ws.monitors.count,
            focusedMonitorIndex: ws.focusedMonitorIndex,
            activeWorkspace: monitor.active,
            activeLayout: monitor.layouts[monitor.active],
            occupiedWorkspaces: occupied,
            activeWindowCount: monitor.workspaces[monitor.active].count,
            masterRatio: Config.shared.masterRatio
        )
    }
}

private final class StatusContentView: NSView {
    private static let spacing: CGFloat = 4
    private static let horizontalPadding: CGFloat = 4
    private static let emptyWorkspaceAlpha: CGFloat = 0.45

    private var segments: [StatusSegment] = []
    private var fontSize: CGFloat = NSFont.menuBarFont(ofSize: 0).pointSize

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    func update(segments: [StatusSegment], fontSize: CGFloat) {
        guard self.segments != segments || self.fontSize != fontSize else { return }
        self.segments = segments
        self.fontSize = fontSize
        setAccessibilityElement(true)
        setAccessibilityLabel(segments.map(\.accessibilityLabel).joined(separator: ", "))
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        let sizes = segments.map { $0.size(fontSize: fontSize) }
        let contentWidth =
            sizes.reduce(0) { $0 + $1.width }
            + CGFloat(max(0, sizes.count - 1)) * Self.spacing
        let contentHeight = sizes.map(\.height).max() ?? fontSize + 6
        return NSSize(
            width: contentWidth + Self.horizontalPadding * 2,
            height: contentHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        for (segment, rect) in segmentFrames() {
            draw(segment, in: rect, ctx: ctx)
        }
    }

    func segment(at point: NSPoint) -> StatusSegment? {
        segmentFrames().first { $0.1.contains(point) }?.0
    }

    private func segmentFrames() -> [(StatusSegment, NSRect)] {
        var x = Self.horizontalPadding
        return segments.map { segment in
            let size = segment.size(fontSize: fontSize)
            let rect = NSRect(x: x, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
            x += size.width + Self.spacing
            return (segment, rect)
        }
    }

    private func draw(_ segment: StatusSegment, in rect: NSRect, ctx: CGContext) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        switch segment {
        case .badge(let number, let active, let occupied):
            if !active && !occupied {
                ctx.setAlpha(Self.emptyWorkspaceAlpha)
            }
            drawWorkspaceBadge(number: number, active: active, in: rect, ctx: ctx)
        case .symbol(let name, let accessibilityLabel):
            drawSymbolBadge(name: name, accessibilityLabel: accessibilityLabel, in: rect, ctx: ctx)
        case .monitor(let number):
            drawMonitorBadge(number: number, in: rect, ctx: ctx)
        case .layout(.monocle, let windowCount, _):
            drawMonocleBadge(windowCount: windowCount, in: rect, ctx: ctx)
        case .layout(.tile, let windowCount, let masterRatio):
            drawTileBadge(windowCount: windowCount, masterRatio: masterRatio, in: rect, ctx: ctx)
        }
    }

    private func drawWorkspaceBadge(number: Int, active: Bool, in rect: NSRect, ctx: CGContext) {
        let badgeRect = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(path)

        if active {
            ctx.setFillColor(badgeColor.cgColor)
            ctx.fillPath()
            ctx.setBlendMode(.destinationOut)
            drawCenteredText("\(number)", in: rect, fontSize: fontSize, color: .black, ctx: ctx)
        } else {
            ctx.setStrokeColor(badgeColor.cgColor)
            ctx.setLineWidth(1)
            ctx.strokePath()
            drawCenteredText("\(number)", in: rect, fontSize: fontSize, color: badgeColor, ctx: ctx)
        }
    }

    private func drawSymbolBadge(name: String, accessibilityLabel: String, in rect: NSRect, ctx: CGContext) {
        let badgeRect = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(path)
        ctx.setStrokeColor(badgeColor.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()

        let configuration = NSImage.SymbolConfiguration(pointSize: fontSize - 3, weight: .semibold)
        guard
            let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityLabel)?
                .withSymbolConfiguration(configuration),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }

        let iconSize = fontSize - 3
        let iconRect = CGRect(
            x: rect.midX - iconSize / 2,
            y: rect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        ctx.saveGState()
        ctx.clip(to: iconRect, mask: cgImage)
        ctx.setFillColor(badgeColor.cgColor)
        ctx.fill(iconRect)
        ctx.restoreGState()
    }

    private func drawMonitorBadge(number: Int, in rect: NSRect, ctx: CGContext) {
        let screenRect = rect.insetBy(dx: 2.5, dy: 3.0)
        let path = CGPath(roundedRect: screenRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
        ctx.addPath(path)
        ctx.setStrokeColor(badgeColor.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        drawCenteredText("\(number)", in: screenRect, fontSize: fontSize, color: badgeColor, ctx: ctx)
    }

    private func drawMonocleBadge(windowCount: Int, in rect: NSRect, ctx: CGContext) {
        let badgeRect = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(path)
        ctx.setStrokeColor(badgeColor.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()

        guard windowCount > 0 else { return }
        let iconSize = fontSize - 5
        let iconX = windowCount > 1 ? badgeRect.minX + 4 : badgeRect.midX - iconSize / 2
        let iconRect = CGRect(x: iconX, y: badgeRect.midY - iconSize / 2, width: iconSize, height: iconSize)
        ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
        ctx.setFillColor(badgeColor.cgColor)
        ctx.fillPath()

        if windowCount > 1 {
            let textRect = CGRect(
                x: iconRect.maxX + 2,
                y: badgeRect.minY,
                width: badgeRect.maxX - iconRect.maxX - 3,
                height: badgeRect.height
            )
            drawCenteredText("\(windowCount)", in: textRect, fontSize: fontSize, color: badgeColor, ctx: ctx)
        }
    }

    private func drawTileBadge(windowCount: Int, masterRatio: CGFloat, in rect: NSRect, ctx: CGContext) {
        let badgeRect = rect.insetBy(dx: 0.5, dy: 0.5)
        ctx.addPath(CGPath(roundedRect: badgeRect, cornerWidth: 3, cornerHeight: 3, transform: nil))
        ctx.setStrokeColor(badgeColor.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()

        let area = badgeRect.insetBy(dx: 3, dy: 3)
        for pane in TileGlyph.rects(windowCount: windowCount, masterRatio: masterRatio, in: area) {
            ctx.addPath(CGPath(roundedRect: pane, cornerWidth: 1, cornerHeight: 1, transform: nil))
        }
        ctx.setFillColor(badgeColor.cgColor)
        ctx.fillPath()
    }
}
