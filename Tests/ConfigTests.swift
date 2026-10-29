import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Config")
struct ConfigTests {
    @Test func validConfigOverridesDefaults() throws {
        let config = try #require(
            Config.parse(
                """
                workspace_count = 4
                master_ratio = 0.62
                modifier = "control"

                [bindings]
                focus_next = "l"
                move_monitor_prev = "shift+comma"

                [[custom]]
                key = "space"
                command = "echo ok"
                """
            )
        )

        #expect(config.workspaceCount == 4)
        #expect(config.masterRatio == CGFloat(0.62))
        #expect(config.modifier == .control)
        let alt = try #require(Config.parse("modifier = \"alt\""))
        #expect(alt.modifier == .option)
        #expect(config.bindings.focusNext.key == Key.l)
        #expect(config.bindings.moveMonitorPrev.shift)
        #expect(config.customBindings.count == 1)
        #expect(config.customBindings[0].key == Key.space)
    }

    @Test func invalidConfigKeepsDefaults() throws {
        let config = try #require(
            Config.parse(
                """
                workspace_count = 42
                master_ratio = -1
                modifier = "hyper"

                [bindings]
                focus_next = "notakey"
                """
            )
        )

        #expect(config.workspaceCount == Config.defaultWorkspaceCount)
        #expect(config.masterRatio == Config.defaultMasterRatio)
        #expect(config.modifier == .option)
        #expect(config.bindings.focusNext.key == Key.j)
    }

    @Test func workspaceCountBoundsStayWithinOneThroughTen() throws {
        for count in 1...10 {
            let config = try #require(Config.parse("workspace_count = \(count)"))
            #expect(config.workspaceCount == count)
            #expect(config.numberKeys.count == count)
        }

        let tooSmall = try #require(Config.parse("workspace_count = 0"))
        let tooLarge = try #require(Config.parse("workspace_count = 11"))
        #expect(tooSmall.workspaceCount == 10)
        #expect(tooLarge.workspaceCount == 10)
    }

    @Test func focusFollowsMouseDefaultOffAndParse() throws {
        #expect(!Config().focusFollowsMouse)
        let config = try #require(Config.parse("focus_follows_mouse = true"))
        #expect(config.focusFollowsMouse)
    }

    @Test func barDefaultsOnAndParsesOff() throws {
        #expect(Config().bar)
        #expect(Config().menuBarIcon)
        let hidden = try #require(Config.parse("bar = false\nmenu_bar_icon = false"))
        #expect(!hidden.bar)
        #expect(!hidden.menuBarIcon)
    }

    @Test func barHighlightDefaultsFillAndParsesOutline() throws {
        #expect(Config().barHighlight == .fill)
        #expect(Config().barTagHighlight == .fill)
        let outline = try #require(Config.parse("bar_highlight = \"outline\""))
        #expect(outline.barHighlight == .outline)
        #expect(outline.barTagHighlight == .outline)
        let alias = try #require(Config.parse("bar_highlight = \"border\""))
        #expect(alias.barHighlight == .outline)
        let text = try #require(Config.parse("bar_highlight = \"outline\"\nbar_tag_highlight = \"text\""))
        #expect(text.barHighlight == .outline)
        #expect(text.barTagHighlight == .text)
    }

    @Test func barFontDefaultsMenubarAndParsesMono() throws {
        #expect(Config().barFont == .menubar)
        let mono = try #require(Config.parse("bar_font = \"mono\""))
        #expect(mono.barFont == .mono)
        let alias = try #require(Config.parse("bar_font = \"monospace\""))
        #expect(alias.barFont == .mono)
    }

    @Test func borderWidthAndRadiusParse() throws {
        #expect(Config().borderWidth == 2)
        #expect(Config().borderRadius == 8)
        let config = try #require(Config.parse("border_width = 3\nborder_radius = 8"))
        #expect(config.borderWidth == 3)
        #expect(config.borderRadius == 8)
    }

    @Test func terminalParsesAppName() throws {
        #expect(Config().terminal.isEmpty)
        let config = try #require(Config.parse("terminal = \"Ghostty\""))
        #expect(config.terminal == "Ghostty")
        let bundle = try #require(Config.parse("terminal = \"com.mitchellh.ghostty\""))
        #expect(bundle.terminal == "com.mitchellh.ghostty")
    }

    @Test func workspaceLetterKeysDefaultOffAndParse() throws {
        #expect(!Config().workspaceLetterKeys)
        let config = try #require(Config.parse("workspace_letter_keys = true"))
        #expect(config.workspaceLetterKeys)
    }

    @Test func unknownKeysDoNotCrashOrCorruptDefaults() throws {
        let config = try #require(
            Config.parse(
                """
                unknown_key = "ignored"

                [unknown_table]
                value = 1
                """
            )
        )

        #expect(config.workspaceCount == Config.defaultWorkspaceCount)
        #expect(config.masterRatio == Config.defaultMasterRatio)
        #expect(config.customBindings.isEmpty)
    }

    @Test func appRulesParseWorkspaceAndFloat() throws {
        let config = try #require(
            Config.parse(
                """
                [[rules]]
                app = "Finder"
                float = true

                [[rules]]
                app = "Safari"
                workspace = 2

                [[rules]]
                app = "com.apple.calculator"
                float = true
                workspace = 9
                """
            )
        )

        #expect(config.rules.count == 3)
        #expect(config.rules[0] == AppRule(app: "Finder", workspace: nil, float: true))
        #expect(config.rules[1] == AppRule(app: "Safari", workspace: 2, float: false))
        #expect(config.rules[2] == AppRule(app: "com.apple.calculator", workspace: 9, float: true))
        #expect(config.rules[1].workspaceIndex == 1)
    }

    @Test func appRulesSkipEmptyAndOutOfRange() throws {
        let config = try #require(
            Config.parse(
                """
                [[rules]]
                app = "Safari"
                workspace = 12

                [[rules]]
                app = "Notes"

                [[rules]]
                app = "Mail"
                workspace = 1
                """
            )
        )

        #expect(config.rules == [AppRule(app: "Mail", workspace: 1, float: false)])
    }

    @Test func appRuleMatchesNameBundleAndExecutable() {
        let rule = AppRule(app: "Safari", workspace: 2, float: false)
        #expect(rule.matches(name: "Safari", bundle: "com.apple.Safari", executable: "Safari"))
        #expect(rule.matches(name: "safari", bundle: nil, executable: nil))
        #expect(rule.matches(name: nil, bundle: "Safari", executable: nil))
        #expect(!rule.matches(name: "Mail", bundle: "com.apple.mail", executable: "Mail"))
    }
}
