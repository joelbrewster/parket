import Testing

@testable import ParketCore

@Suite("Hotkey planner")
struct HotkeyPlannerTests {
    @Test func customBindingsWinOverWorkspaceAndBuiltins() {
        var config = Config()
        config.workspaceCount = 1
        config.customBindings = [
            Binding(key: Key.one, command: "echo workspace"),
            Binding(key: Key.j, command: "echo focus"),
        ]

        let plan = HotkeyPlanner.plan(config: config)

        #expect(plan.registrations[0].action == .customCommand(index: 1, command: "echo workspace"))
        #expect(plan.registrations[1].action == .customCommand(index: 2, command: "echo focus"))
        #expect(
            plan.skipped.contains {
                $0.reason == .duplicate
                    && $0.skippedLabel == "switch_workspace_1"
                    && $0.keptLabel == "custom#1"
            }
        )
        #expect(
            plan.skipped.contains {
                $0.reason == .duplicate
                    && $0.skippedLabel == "focus_next"
                    && $0.keptLabel == "custom#2"
            }
        )
    }

    @Test func workspaceBindingsRespectWorkspaceCount() {
        var config = Config()
        config.workspaceCount = 3
        config.customBindings = []

        let plan = HotkeyPlanner.plan(config: config)
        let labels = plan.registrations.map(\.diagnosticLabel)

        #expect(labels.contains("switch_workspace_1"))
        #expect(labels.contains("switch_workspace_2"))
        #expect(labels.contains("switch_workspace_3"))
        #expect(!labels.contains("switch_workspace_4"))
        #expect(labels.contains("move_workspace_1"))
        #expect(labels.contains("move_workspace_2"))
        #expect(labels.contains("move_workspace_3"))
        #expect(!labels.contains("move_workspace_4"))
    }

    @Test func zeroKeyBindsTenthWorkspace() {
        var config = Config()
        config.customBindings = []

        let plan = HotkeyPlanner.plan(config: config)

        #expect(plan.registrations.contains { $0.chord.key == Key.zero && $0.action == .switchWorkspace(9) })
        #expect(
            plan.registrations.contains { $0.chord.key == Key.zero && $0.chord.shift && $0.action == .moveWorkspace(9) }
        )
    }

    @Test func letterKeysAliasNumberRowWhenEnabled() {
        var config = Config()
        config.customBindings = []

        let off = HotkeyPlanner.plan(config: config)
        #expect(!off.registrations.contains { $0.chord.key == Key.q })

        config.workspaceLetterKeys = true
        let on = HotkeyPlanner.plan(config: config)
        #expect(on.registrations.contains { $0.chord.key == Key.q && $0.action == .switchWorkspace(0) })
        #expect(on.registrations.contains { $0.chord.key == Key.p && $0.action == .switchWorkspace(9) })
        #expect(on.registrations.contains { $0.chord.key == Key.p && $0.chord.shift && $0.action == .moveWorkspace(9) })
        #expect(on.skipped.isEmpty)
    }

    @Test func letterKeysRespectWorkspaceCount() {
        var config = Config()
        config.workspaceCount = 3
        config.workspaceLetterKeys = true
        config.customBindings = []

        let plan = HotkeyPlanner.plan(config: config)

        #expect(plan.registrations.contains { $0.chord.key == Key.e })
        #expect(!plan.registrations.contains { $0.chord.key == Key.r })
    }

    @Test func commandTabIsReservedForSystem() {
        var config = Config()
        config.modifier = .command
        config.customBindings = []

        let plan = HotkeyPlanner.plan(config: config)

        #expect(
            plan.skipped.contains {
                $0.reason == .reserved && $0.skippedLabel == "last_workspace"
            }
        )
        #expect(
            !plan.registrations.contains {
                $0.chord.modifier == .command && $0.chord.key == Key.tab
            }
        )
    }

    @Test func duplicateBindingsKeepFirstAndReportSkipped() {
        var config = Config()
        config.workspaceCount = 1
        config.customBindings = []
        config.bindings.focusPrev = config.bindings.focusNext

        let plan = HotkeyPlanner.plan(config: config)
        let registeredFocus = plan.registrations.filter { $0.diagnosticLabel == "focus_next" }

        #expect(registeredFocus.count == 1)
        #expect(
            plan.skipped.contains {
                $0.reason == .duplicate
                    && $0.skippedLabel == "focus_prev"
                    && $0.keptLabel == "focus_next"
            }
        )
    }
}
