import AppKit

@MainActor
package final class PermissionWindowController: NSWindowController {
    package static let shared = PermissionWindowController()

    private let issueLabel = PermissionWindowController.wrappingLabel("")

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 200),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "parket"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.isMovableByWindowBackground = true
        super.init(window: window)
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    package func show(snapshot: PermissionSnapshot, startupIssue: String?) {
        update(snapshot: snapshot, startupIssue: startupIssue)
        guard let window else { return }
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    package func update(snapshot _: PermissionSnapshot, startupIssue: String?) {
        issueLabel.stringValue = startupIssue ?? ""
        issueLabel.isHidden = startupIssue == nil || startupIssue?.isEmpty == true
        sizeToFit()
    }

    package func closeWindow() {
        close()
    }

    private func buildContent() {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = Self.label("Accessibility Access Needed", style: .headline, color: .labelColor)
        let body = Self.wrappingLabel(
            "Parket needs Accessibility to move and resize windows. Open System Settings, enable parket under Privacy & Security → Accessibility, then click Check Again."
        )
        body.textColor = .secondaryLabelColor
        issueLabel.textColor = .secondaryLabelColor
        issueLabel.font = NSFont.preferredFont(forTextStyle: .callout)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false
        for view in [title, body, issueLabel] {
            textStack.addArrangedSubview(view)
        }
        textStack.setCustomSpacing(10, after: body)

        let openSettings = NSButton(
            title: "Open System Settings",
            target: self,
            action: #selector(openAccessibilitySettings)
        )
        openSettings.bezelStyle = .rounded
        openSettings.keyEquivalent = "\r"

        let checkAgain = NSButton(
            title: "Check Again",
            target: self,
            action: #selector(recheckPermissions)
        )
        checkAgain.bezelStyle = .rounded

        let buttons = NSStackView(views: [checkAgain, openSettings])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 12
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(icon)
        root.addSubview(textStack)
        root.addSubview(buttons)
        window?.contentView = root
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            icon.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
            textStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            textStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),

            buttons.topAnchor.constraint(greaterThanOrEqualTo: textStack.bottomAnchor, constant: 20),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: icon.bottomAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            buttons.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 20),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
        ])
        sizeToFit()
    }

    private func sizeToFit() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        window.setContentSize(NSSize(width: 440, height: max(size.height, 160)))
    }

    @objc private func openAccessibilitySettings() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
        ParketRuntime.shared.refreshPermissions(prompt: false)
    }

    @objc private func recheckPermissions() {
        ParketRuntime.shared.refreshPermissions(prompt: false)
    }

    private static func label(_ text: String, style: NSFont.TextStyle, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.preferredFont(forTextStyle: style)
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        return field
    }

    private static func wrappingLabel(_ text: String) -> NSTextField {
        let field = label(text, style: .body, color: .labelColor)
        field.preferredMaxLayoutWidth = 320
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
}
