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

    @Test func barFontDefaultsMenubarAndParsesMono() throws {
        #expect(Config().barFont == .menubar)
        let mono = try #require(Config.parse("bar_font = \"mono\""))
        #expect(mono.barFont == .mono)
        let alias = try #require(Config.parse("bar_font = \"monospace\""))
        #expect(alias.barFont == .mono)
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
}
