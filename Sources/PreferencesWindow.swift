import AppKit
import UniformTypeIdentifiers

@MainActor
package final class PreferencesWindowController: NSWindowController {
    private static var instance: PreferencesWindowController?

    package static var shared: PreferencesWindowController {
        if let instance { return instance }
        let created = PreferencesWindowController()
        instance = created
        return created
    }

    package static func syncIfVisible() {
        instance?.syncIfVisible()
    }

    private var syncing = false
    private let barCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let menuBarIconCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let focusFollowsMouseCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hyperCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let letterKeysCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let highlightPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let tagHighlightPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let outerGapPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let windowGapPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let borderWidthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let borderRadiusPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let workspaceCountPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let masterRatioPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let modifierPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let terminalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let overlayModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let overlayPathLabel = NSTextField(labelWithString: "None")
    private let chooseOverlayButton = NSButton(title: "Choose...", target: nil, action: nil)
    private let clearOverlayButton = NSButton(title: "Clear", target: nil, action: nil)

    private init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "parket Settings"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        super.init(window: window)
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    package func show() {
        rebuildTerminalPopup()
        sync()
        guard let window else { return }
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    package func syncIfVisible() {
        guard window?.isVisible == true else { return }
        sync()
    }

    private func sync() {
        syncing = true
        defer { syncing = false }
        let config = Config.shared
        barCheckbox.state = config.bar ? .on : .off
        menuBarIconCheckbox.state = config.menuBarIcon ? .on : .off
        focusFollowsMouseCheckbox.state = config.focusFollowsMouse ? .on : .off
        hyperCheckbox.state = config.hyper ? .on : .off
        letterKeysCheckbox.state = config.workspaceLetterKeys ? .on : .off
        select(fontPopup, string: config.barFont.rawValue)
        select(highlightPopup, string: config.barHighlight.rawValue)
        select(tagHighlightPopup, string: config.barTagHighlight.rawValue)
        select(outerGapPopup, number: config.outerGap)
        select(windowGapPopup, number: config.windowGap)
        select(borderWidthPopup, number: config.borderWidth)
        select(borderRadiusPopup, number: config.borderRadius)
        select(workspaceCountPopup, integer: config.workspaceCount)
        select(masterRatioPopup, number: config.masterRatio)
        select(modifierPopup, string: config.modifier.rawValue)
        selectTerminal()
        syncOverlay()
    }

    private func buildContent() {
        bind(barCheckbox, #selector(toggleBar))
        bind(menuBarIconCheckbox, #selector(toggleMenuBarIcon))
        bind(focusFollowsMouseCheckbox, #selector(toggleFocusFollowsMouse))
        bind(hyperCheckbox, #selector(toggleHyper))
        bind(letterKeysCheckbox, #selector(toggleLetterKeys))

        fill(
            fontPopup,
            [
                ("Menu Bar", BarFont.menubar.rawValue),
                ("Yakshaven", BarFont.mono.rawValue),
            ], action: #selector(chooseFont(_:)))
        fillHighlight(highlightPopup, action: #selector(chooseHighlight(_:)))
        fillHighlight(tagHighlightPopup, action: #selector(chooseTagHighlight(_:)))
        fillNumbers(outerGapPopup, [0, 2, 4, 8, 12, 16, 24], suffix: " px", action: #selector(chooseOuterGap(_:)))
        fillNumbers(windowGapPopup, [0, 2, 4, 8, 12, 16, 24], suffix: " px", action: #selector(chooseWindowGap(_:)))
        fillNumbers(borderWidthPopup, [1, 2, 3, 4], suffix: " px", action: #selector(chooseBorderWidth(_:)))
        fillNumbers(
            borderRadiusPopup, [0, 2, 4, 6, 8, 10, 12], suffix: " px", action: #selector(chooseBorderRadius(_:)))
        fillIntegers(workspaceCountPopup, Array(1...10), action: #selector(chooseWorkspaceCount(_:)))
        fillPercents(
            masterRatioPopup, Array(stride(from: 30, through: 70, by: 5)), action: #selector(chooseMasterRatio(_:)))
        fill(
            modifierPopup,
            [
                ("Option", HotkeyModifier.option.rawValue),
                ("Control", HotkeyModifier.control.rawValue),
                ("Command", HotkeyModifier.command.rawValue),
            ], action: #selector(chooseModifier(_:)))
        terminalPopup.target = self
        terminalPopup.action = #selector(chooseTerminal(_:))
        terminalPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        rebuildTerminalPopup()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let appearance = grid([
            row("Show Bar", barCheckbox),
            row("Show Menu Bar Icon", menuBarIconCheckbox),
            row("Bar Font", fontPopup),
            row("Window Highlight", highlightPopup),
            row("Tag Highlight", tagHighlightPopup),
            row("Border Width", borderWidthPopup),
            row("Border Radius", borderRadiusPopup),
        ])
        let tiling = grid([
            row("Workspaces", workspaceCountPopup),
            row("Master Width", masterRatioPopup),
            row("Outside Space", outerGapPopup),
            row("Window Gap", windowGapPopup),
            row("Focus Follows Mouse", focusFollowsMouseCheckbox),
        ])
        let keys = grid([
            row("Modifier", modifierPopup),
            row("Hyper Keys", hyperCheckbox),
            row("Letter Workspace Keys", letterKeysCheckbox),
        ])
        let terminal = grid([
            row("App", terminalPopup)
        ])

        fill(
            overlayModePopup,
            [
                ("Center", DesktopOverlayMode.center.rawValue),
                ("Tile", DesktopOverlayMode.tile.rawValue),
                ("Fill", DesktopOverlayMode.fill.rawValue),
            ], action: #selector(chooseOverlayMode(_:)))
        chooseOverlayButton.target = self
        chooseOverlayButton.action = #selector(chooseOverlay)
        chooseOverlayButton.bezelStyle = .rounded
        clearOverlayButton.target = self
        clearOverlayButton.action = #selector(clearOverlay)
        clearOverlayButton.bezelStyle = .rounded
        overlayPathLabel.lineBreakMode = .byTruncatingMiddle
        overlayPathLabel.maximumNumberOfLines = 1
        overlayPathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let overlayButtons = NSStackView(views: [chooseOverlayButton, clearOverlayButton])
        overlayButtons.orientation = .horizontal
        overlayButtons.spacing = 8
        overlayButtons.alignment = .centerY
        let desktop = grid([
            row("Image", overlayPathLabel),
            row("", overlayButtons),
            row("Placement", overlayModePopup),
        ])

        let configNote = Self.label(
            "Keymaps, rules, and custom binds stay in ~/.config/parket/config.toml",
            style: .callout,
            color: .secondaryLabelColor
        )
        configNote.preferredMaxLayoutWidth = 400
        configNote.lineBreakMode = .byWordWrapping
        configNote.maximumNumberOfLines = 0

        let openConfig = NSButton(title: "Open Config", target: self, action: #selector(openConfig))
        openConfig.bezelStyle = .rounded
        let reloadConfig = NSButton(title: "Reload Config", target: self, action: #selector(reloadConfig))
        reloadConfig.bezelStyle = .rounded
        let buttons = NSStackView(views: [openConfig, reloadConfig])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.alignment = .centerY

        for view in [
            Self.header("Appearance"), appearance,
            Self.header("Desktop"), desktop,
            Self.header("Tiling"), tiling,
            Self.header("Keys"), keys,
            Self.header("Terminal"), terminal,
            configNote, buttons,
        ] {
            stack.addArrangedSubview(view)
        }
        stack.setCustomSpacing(6, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(6, after: stack.arrangedSubviews[2])
        stack.setCustomSpacing(6, after: stack.arrangedSubviews[4])
        stack.setCustomSpacing(6, after: stack.arrangedSubviews[6])
        stack.setCustomSpacing(6, after: stack.arrangedSubviews[8])
        stack.setCustomSpacing(8, after: configNote)

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        window?.contentView = root
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            appearance.widthAnchor.constraint(equalTo: stack.widthAnchor),
            desktop.widthAnchor.constraint(equalTo: stack.widthAnchor),
            tiling.widthAnchor.constraint(equalTo: stack.widthAnchor),
            keys.widthAnchor.constraint(equalTo: stack.widthAnchor),
            terminal.widthAnchor.constraint(equalTo: stack.widthAnchor),
            overlayPathLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
        ])
        sizeToFit()
        sync()
    }

    private func sizeToFit() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        window.setContentSize(NSSize(width: 460, height: max(size.height, 200)))
    }

    private func bind(_ checkbox: NSButton, _ action: Selector) {
        checkbox.target = self
        checkbox.action = action
    }

    private func fill(_ popup: NSPopUpButton, _ items: [(String, String)], action: Selector) {
        popup.removeAllItems()
        for (title, value) in items {
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = value
        }
        popup.target = self
        popup.action = action
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    private func fillHighlight(_ popup: NSPopUpButton, action: Selector) {
        fill(
            popup,
            [
                ("Text", BarHighlight.text.rawValue),
                ("Fill", BarHighlight.fill.rawValue),
                ("Outline", BarHighlight.outline.rawValue),
            ], action: action)
    }

    private func fillNumbers(_ popup: NSPopUpButton, _ values: [Int], suffix: String, action: Selector) {
        popup.removeAllItems()
        for value in values {
            popup.addItem(withTitle: "\(value)\(suffix)")
            popup.lastItem?.representedObject = Double(value)
        }
        popup.target = self
        popup.action = action
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    private func fillIntegers(_ popup: NSPopUpButton, _ values: [Int], action: Selector) {
        popup.removeAllItems()
        for value in values {
            popup.addItem(withTitle: "\(value)")
            popup.lastItem?.tag = value
        }
        popup.target = self
        popup.action = action
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    private func fillPercents(_ popup: NSPopUpButton, _ values: [Int], action: Selector) {
        popup.removeAllItems()
        for value in values {
            popup.addItem(withTitle: "\(value)%")
            popup.lastItem?.representedObject = Double(value) / 100
        }
        popup.target = self
        popup.action = action
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    private func rebuildTerminalPopup() {
        terminalPopup.removeAllItems()
        terminalPopup.addItem(withTitle: "System Default")
        terminalPopup.lastItem?.representedObject = ""
        for name in TerminalLauncher.installedNames() {
            terminalPopup.addItem(withTitle: name)
            terminalPopup.lastItem?.representedObject = name
        }
        let current = Config.shared.terminal
        if !current.isEmpty,
            !terminalPopup.itemArray.contains(where: { ($0.representedObject as? String) == current })
        {
            terminalPopup.addItem(withTitle: current)
            terminalPopup.lastItem?.representedObject = current
        }
        terminalPopup.addItem(withTitle: "Choose...")
    }

    private func grid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        for index in 0..<grid.numberOfRows {
            grid.row(at: index).yPlacement = .center
        }
        grid.translatesAutoresizingMaskIntoConstraints = false
        return grid
    }

    private func row(_ title: String, _ control: NSView) -> [NSView] {
        [Self.label(title, style: .body, color: .labelColor), control]
    }

    private func select(_ popup: NSPopUpButton, string: String) {
        if let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? String) == string }) {
            popup.selectItem(at: index)
        }
    }

    private func select(_ popup: NSPopUpButton, number: CGFloat) {
        if let index = popup.itemArray.firstIndex(where: {
            let stored = ($0.representedObject as? Double).map { CGFloat($0) }
            return stored.map { abs($0 - number) < 0.001 } ?? false
        }) {
            popup.selectItem(at: index)
        }
    }

    private func select(_ popup: NSPopUpButton, integer: Int) {
        if let index = popup.itemArray.firstIndex(where: { $0.tag == integer }) {
            popup.selectItem(at: index)
        }
    }

    private func selectTerminal() {
        let current = Config.shared.terminal
        if let index = terminalPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == current }) {
            terminalPopup.selectItem(at: index)
        } else {
            terminalPopup.selectItem(at: 0)
        }
    }

    @objc private func toggleBar() {
        guard !syncing else { return }
        Config.setChrome(bar: barCheckbox.state == .on)
    }

    @objc private func toggleMenuBarIcon() {
        guard !syncing else { return }
        Config.setChrome(menuBarIcon: menuBarIconCheckbox.state == .on)
    }

    @objc private func toggleFocusFollowsMouse() {
        guard !syncing else { return }
        Config.setFocusFollowsMouse(focusFollowsMouseCheckbox.state == .on)
    }

    @objc private func toggleHyper() {
        guard !syncing else { return }
        Config.setHyper(hyperCheckbox.state == .on)
    }

    @objc private func toggleLetterKeys() {
        guard !syncing else { return }
        Config.setWorkspaceLetterKeys(letterKeysCheckbox.state == .on)
    }

    @objc private func chooseFont(_ sender: NSPopUpButton) {
        guard !syncing, let raw = sender.selectedItem?.representedObject as? String else { return }
        Config.setBarFont(raw == BarFont.mono.rawValue ? .mono : .menubar)
    }

    @objc private func chooseHighlight(_ sender: NSPopUpButton) {
        guard !syncing, let value = highlight(from: sender) else { return }
        Config.setBarHighlight(value)
    }

    @objc private func chooseTagHighlight(_ sender: NSPopUpButton) {
        guard !syncing, let value = highlight(from: sender) else { return }
        Config.setBarTagHighlight(value)
    }

    @objc private func chooseOuterGap(_ sender: NSPopUpButton) {
        guard !syncing, let value = number(from: sender) else { return }
        Config.setOuterGap(value)
    }

    @objc private func chooseWindowGap(_ sender: NSPopUpButton) {
        guard !syncing, let value = number(from: sender) else { return }
        Config.setWindowGap(value)
    }

    @objc private func chooseBorderWidth(_ sender: NSPopUpButton) {
        guard !syncing, let value = number(from: sender) else { return }
        Config.setBorderWidth(value)
    }

    @objc private func chooseBorderRadius(_ sender: NSPopUpButton) {
        guard !syncing, let value = number(from: sender) else { return }
        Config.setBorderRadius(value)
    }

    @objc private func chooseWorkspaceCount(_ sender: NSPopUpButton) {
        guard !syncing, let item = sender.selectedItem else { return }
        Config.setWorkspaceCount(item.tag)
    }

    @objc private func chooseMasterRatio(_ sender: NSPopUpButton) {
        guard !syncing, let value = number(from: sender) else { return }
        Config.setMasterRatio(value)
    }

    @objc private func chooseModifier(_ sender: NSPopUpButton) {
        guard !syncing, let raw = sender.selectedItem?.representedObject as? String else { return }
        switch raw {
        case HotkeyModifier.control.rawValue:
            Config.setModifier(.control)
        case HotkeyModifier.command.rawValue:
            Config.setModifier(.command)
        default:
            Config.setModifier(.option)
        }
    }

    @objc private func chooseTerminal(_ sender: NSPopUpButton) {
        guard !syncing else { return }
        if sender.selectedItem?.representedObject == nil {
            selectTerminal()
            chooseTerminalApp()
            return
        }
        Config.setTerminal(sender.selectedItem?.representedObject as? String ?? "")
    }

    @objc private func chooseTerminalApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Config.setTerminal(url.deletingPathExtension().lastPathComponent)
            self.rebuildTerminalPopup()
            self.sync()
        }
    }

    @objc private func chooseOverlay() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png]
        panel.directoryURL = Config.url.deletingLastPathComponent()
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Config.setDesktopOverlay(url.path)
            self.syncOverlay()
        }
    }

    @objc private func clearOverlay() {
        Config.setDesktopOverlay("")
        syncOverlay()
    }

    @objc private func chooseOverlayMode(_ sender: NSPopUpButton) {
        guard !syncing, let raw = sender.selectedItem?.representedObject as? String else { return }
        switch raw {
        case DesktopOverlayMode.tile.rawValue:
            Config.setDesktopOverlayMode(.tile)
        case DesktopOverlayMode.fill.rawValue:
            Config.setDesktopOverlayMode(.fill)
        default:
            Config.setDesktopOverlayMode(.center)
        }
    }

    private func syncOverlay() {
        select(overlayModePopup, string: Config.shared.desktopOverlayMode.rawValue)
        let path = Config.shared.desktopOverlay
        if path.isEmpty {
            overlayPathLabel.stringValue = "None"
            overlayPathLabel.toolTip = nil
            clearOverlayButton.isEnabled = false
        } else {
            overlayPathLabel.stringValue = (path as NSString).lastPathComponent
            overlayPathLabel.toolTip = path
            clearOverlayButton.isEnabled = true
        }
    }

    @objc private func openConfig() {
        Config.openConfig()
    }

    @objc private func reloadConfig() {
        ParketRuntime.shared.reloadConfig()
        rebuildTerminalPopup()
        sync()
    }

    private func highlight(from popup: NSPopUpButton) -> BarHighlight? {
        guard let raw = popup.selectedItem?.representedObject as? String else { return nil }
        switch raw {
        case BarHighlight.fill.rawValue: return .fill
        case BarHighlight.outline.rawValue: return .outline
        case BarHighlight.text.rawValue: return .text
        default: return nil
        }
    }

    private func number(from popup: NSPopUpButton) -> CGFloat? {
        (popup.selectedItem?.representedObject as? Double).map { CGFloat($0) }
    }

    private static func header(_ text: String) -> NSTextField {
        label(text, style: .headline, color: .labelColor)
    }

    private static func label(_ text: String, style: NSFont.TextStyle, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.preferredFont(forTextStyle: style)
        field.textColor = color
        return field
    }
}
