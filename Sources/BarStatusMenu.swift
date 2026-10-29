import AppKit

enum StatusHover: Equatable {
    case music
    case weather
    case clock
}

@MainActor
final class BarStatusMenu: NSObject {
    static let shared = BarStatusMenu()

    private var panel: NSPanel?
    private var kind: StatusHover?
    private var showWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    private var insideBar = false
    private var insideMenu = false

    private override init() {
        super.init()
    }

    func enter(_ kind: StatusHover, rect: NSRect, in view: NSView) {
        insideBar = true
        hideWork?.cancel()
        if self.kind == kind, panel?.isVisible == true { return }
        showWork?.cancel()
        let work = DispatchWorkItem { [weak view] in
            guard let view else { return }
            self.present(kind, rect: rect, in: view)
        }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func leaveBar() {
        insideBar = false
        showWork?.cancel()
        scheduleHide()
    }

    fileprivate func enterMenu() {
        insideMenu = true
        hideWork?.cancel()
    }

    fileprivate func leaveMenu() {
        insideMenu = false
        scheduleHide()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem {
            guard !self.insideBar, !self.insideMenu else { return }
            self.panel?.orderOut(nil)
            self.kind = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func present(_ kind: StatusHover, rect: NSRect, in view: NSView) {
        guard let window = view.window else { return }
        let content = contentView(for: kind)
        let panel = panel ?? makePanel()
        panel.contentView = content
        content.layoutSubtreeIfNeeded()
        var size = content.fittingSize
        if size.width < 80 || size.height < 24 {
            size = NSSize(width: 220, height: 48)
        }
        let fitted = NSSize(width: max(size.width, 180), height: max(size.height, 40))
        content.frame = NSRect(origin: .zero, size: fitted)
        let item = window.convertToScreen(view.convert(rect, to: nil))
        var origin = NSPoint(x: item.minX, y: item.minY - fitted.height - 4)
        if let screen = window.screen ?? NSScreen.main {
            origin.x = min(origin.x, screen.visibleFrame.maxX - fitted.width - 4)
            origin.x = max(origin.x, screen.visibleFrame.minX + 4)
        }
        panel.setFrame(NSRect(origin: origin, size: fitted), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        self.kind = kind
    }

    private func makePanel() -> NSPanel {
        let panel = HoverPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.backgroundColor = MenuBarChrome.color
        panel.isOpaque = true
        return panel
    }

    private func contentView(for kind: StatusHover) -> NSView {
        switch kind {
        case .music:
            return musicView()
        case .weather:
            return weatherView()
        case .clock:
            return calendarView()
        }
    }

    private func musicView() -> NSView {
        let prev = button("Prev") { NowPlaying.shared.previous() }
        let play = button("Play/Pause") { NowPlaying.shared.playPause() }
        let next = button("Next") { NowPlaying.shared.next() }
        let stack = NSStackView(views: [prev, play, next])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        return wrap(stack)
    }

    private func weatherView() -> NSView {
        let days = Weather.shared.days
        let rows: [NSView] = days.isEmpty
            ? [label("No forecast yet")]
            : days.map { day in
                let name = label(day.name)
                name.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                let detail = label(day.detail)
                detail.textColor = .secondaryLabelColor
                let row = NSStackView(views: [name, detail])
                row.orientation = .horizontal
                row.distribution = .fill
                row.spacing = 12
                return row
            }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        return wrap(stack)
    }

    private func calendarView() -> NSView {
        let calendar = MiniCalendar(frame: NSRect(x: 0, y: 0, width: 168, height: 148))
        calendar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            calendar.widthAnchor.constraint(equalToConstant: 168),
            calendar.heightAnchor.constraint(equalToConstant: 148),
        ])
        return wrap(calendar)
    }

    private func wrap(_ inner: NSView) -> NSView {
        inner.translatesAutoresizingMaskIntoConstraints = false
        let catcher = HoverCatcher()
        catcher.wantsLayer = true
        catcher.layer?.backgroundColor = MenuBarChrome.color.cgColor
        catcher.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: catcher.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: catcher.trailingAnchor),
            inner.topAnchor.constraint(equalTo: catcher.topAnchor),
            inner.bottomAnchor.constraint(equalTo: catcher.bottomAnchor),
        ])
        return catcher
    }

    private func button(_ title: String, _ onClick: @escaping () -> Void) -> NSButton {
        let button = MenuButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.font = Config.shared.barFont.nsFont()
        button.onClick = onClick
        return button
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = Config.shared.barFont.nsFont()
        field.textColor = .labelColor
        return field
    }
}

private final class MiniCalendar: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 168, height: 148) }

    override func draw(_ dirtyRect: NSRect) {
        MenuBarChrome.color.setFill()
        bounds.fill()
        let font = Config.shared.barFont.nsFont()
        let small = NSFont(name: font.fontName, size: 11) ?? font
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let header = DateFormatter()
        header.locale = .current
        header.dateFormat = "MMM yyyy"
        drawString(header.string(from: now), font: font, color: .labelColor, in: NSRect(x: 8, y: 6, width: bounds.width - 16, height: 18), align: .center)

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        let cellW = (bounds.width - 8) / 7
        var y: CGFloat = 28
        for (i, symbol) in ordered.enumerated() {
            drawString(
                symbol,
                font: small,
                color: .tertiaryLabelColor,
                in: NSRect(x: 4 + CGFloat(i) * cellW, y: y, width: cellW, height: 14),
                align: .center
            )
        }
        y += 16
        let startWeekday = calendar.component(.weekday, from: month)
        var offset = startWeekday - calendar.firstWeekday
        if offset < 0 { offset += 7 }
        let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let today = calendar.component(.day, from: now)
        for day in 1...days {
            let index = offset + day - 1
            let col = index % 7
            let row = index / 7
            let rect = NSRect(
                x: 4 + CGFloat(col) * cellW,
                y: y + CGFloat(row) * 16,
                width: cellW,
                height: 16
            )
            if day == today {
                MenuBarChrome.accent.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 1), xRadius: 3, yRadius: 3).fill()
            }
            drawString(
                "\(day)",
                font: small,
                color: day == today ? .white : .labelColor,
                in: rect,
                align: .center
            )
        }
    }

    private func drawString(_ text: String, font: NSFont, color: NSColor, in rect: NSRect, align: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align
        let attr = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
        let size = attr.size()
        let textRect = NSRect(
            x: rect.minX,
            y: rect.minY + (rect.height - size.height) / 2,
            width: rect.width,
            height: size.height
        )
        attr.draw(with: textRect, options: [.usesLineFragmentOrigin])
    }
}

private final class HoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class MenuButton: NSButton {
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        highlight(true)
        onClick?()
        highlight(false)
    }
}

private final class HoverCatcher: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        BarStatusMenu.shared.enterMenu()
    }

    override func mouseExited(with event: NSEvent) {
        BarStatusMenu.shared.leaveMenu()
    }
}
