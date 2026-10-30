package enum HotkeyAction: Equatable {
    case switchWorkspace(Int)
    case moveWorkspace(Int)
    case focusMonitor(Int)
    case moveWindowToMonitor(Int)
    case switchToLastWorkspace
    case focusNext
    case focusPrev
    case swapMaster
    case toggleLayout
    case toggleFloating
    case toggleBar
    case spawnTerminal
    case decreaseMaster
    case increaseMaster
    case reloadConfig
    case renameWorkspace
    case customCommand(index: Int, command: String)

    package var diagnosticLabel: String {
        switch self {
        case .switchWorkspace(let index):
            return "switch_workspace_\(index + 1)"
        case .moveWorkspace(let index):
            return "move_workspace_\(index + 1)"
        case .focusMonitor(let offset):
            return offset < 0 ? "focus_monitor_prev" : "focus_monitor_next"
        case .moveWindowToMonitor(let offset):
            return offset < 0 ? "move_monitor_prev" : "move_monitor_next"
        case .switchToLastWorkspace:
            return "last_workspace"
        case .focusNext:
            return "focus_next"
        case .focusPrev:
            return "focus_prev"
        case .swapMaster:
            return "swap_master"
        case .toggleLayout:
            return "toggle_layout"
        case .toggleFloating:
            return "toggle_floating"
        case .toggleBar:
            return "toggle_bar"
        case .spawnTerminal:
            return "spawn_terminal"
        case .decreaseMaster:
            return "decrease_master"
        case .increaseMaster:
            return "increase_master"
        case .reloadConfig:
            return "reload_config"
        case .renameWorkspace:
            return "rename_workspace"
        case .customCommand(let index, _):
            return "custom#\(index)"
        }
    }

    package var traceName: String {
        switch self {
        case .switchWorkspace:
            return "workspace_switch"
        case .moveWorkspace:
            return "move_workspace"
        case .focusMonitor:
            return "focus_monitor"
        case .moveWindowToMonitor:
            return "move_monitor"
        case .switchToLastWorkspace:
            return "last_workspace"
        case .focusNext:
            return "focus_next"
        case .focusPrev:
            return "focus_prev"
        case .swapMaster:
            return "swap_master"
        case .toggleLayout:
            return "toggle_layout"
        case .toggleFloating:
            return "toggle_floating"
        case .toggleBar:
            return "toggle_bar"
        case .spawnTerminal:
            return "spawn_terminal"
        case .decreaseMaster:
            return "decrease_master"
        case .increaseMaster:
            return "increase_master"
        case .reloadConfig:
            return "reload_config"
        case .renameWorkspace:
            return "rename_workspace"
        case .customCommand:
            return "custom_command"
        }
    }

    package var traceMetadata: [String: Int] {
        switch self {
        case .switchWorkspace(let index), .moveWorkspace(let index):
            return ["target_workspace": index + 1]
        case .focusMonitor(let offset), .moveWindowToMonitor(let offset):
            return ["monitor_offset": offset]
        case .customCommand(let index, _):
            return ["custom_index": index]
        default:
            return [:]
        }
    }
}

package struct HotkeyChord: Hashable, Equatable {
    let modifier: HotkeyModifier
    let shift: Bool
    let key: UInt16

    package var diagnosticText: String {
        var parts = [modifier.rawValue]
        if shift {
            parts.append("shift")
        }
        parts.append(Key.name(for: key))
        return parts.joined(separator: "+")
    }
}

package struct PlannedHotkey: Equatable {
    let id: UInt32
    let chord: HotkeyChord
    let action: HotkeyAction

    package var diagnosticLabel: String {
        action.diagnosticLabel
    }
}

package enum HotkeySkipReason: String, Equatable {
    case duplicate
    case reserved
}

package struct SkippedHotkey: Equatable {
    let chord: HotkeyChord
    let skippedLabel: String
    let reason: HotkeySkipReason
    let keptLabel: String?
}

package struct FailedHotkeyRegistration: Equatable {
    let chord: HotkeyChord
    let label: String
    let osStatus: Int32
}

package struct HotkeyPlan: Equatable {
    let registrations: [PlannedHotkey]
    let skipped: [SkippedHotkey]
}

package enum HotkeyPlanner {
    package static func plan(config: Config) -> HotkeyPlan {
        var registrations: [PlannedHotkey] = []
        var skipped: [SkippedHotkey] = []
        var occupied: [HotkeyChord: PlannedHotkey] = [:]
        var nextID: UInt32 = 1

        func add(key: UInt16, shift: Bool, action: HotkeyAction) {
            let chord = HotkeyChord(modifier: config.modifier, shift: shift, key: key)
            if isReserved(chord) {
                skipped.append(
                    SkippedHotkey(
                        chord: chord,
                        skippedLabel: action.diagnosticLabel,
                        reason: .reserved,
                        keptLabel: nil
                    )
                )
                return
            }
            if let existing = occupied[chord] {
                skipped.append(
                    SkippedHotkey(
                        chord: chord,
                        skippedLabel: action.diagnosticLabel,
                        reason: .duplicate,
                        keptLabel: existing.diagnosticLabel
                    )
                )
                return
            }

            let registration = PlannedHotkey(id: nextID, chord: chord, action: action)
            registrations.append(registration)
            occupied[chord] = registration
            nextID += 1
        }

        for index in config.customBindings.indices {
            let binding = config.customBindings[index]
            add(
                key: binding.key,
                shift: binding.shift,
                action: .customCommand(index: index + 1, command: binding.command)
            )
        }

        let workspaceCount = max(0, min(config.workspaceCount, Key.numberKeys.count))
        for index in 0..<workspaceCount {
            let key = Key.numberKeys[index]
            add(key: key, shift: false, action: .switchWorkspace(index))
            add(key: key, shift: true, action: .moveWorkspace(index))
        }

        if config.workspaceLetterKeys {
            for index in 0..<min(workspaceCount, Key.letterKeys.count) {
                let key = Key.letterKeys[index]
                add(key: key, shift: false, action: .switchWorkspace(index))
                add(key: key, shift: true, action: .moveWorkspace(index))
            }
        }

        let bindings = config.bindings
        add(key: bindings.focusNext.key, shift: bindings.focusNext.shift, action: .focusNext)
        add(key: bindings.focusPrev.key, shift: bindings.focusPrev.shift, action: .focusPrev)
        add(key: bindings.swapMaster.key, shift: bindings.swapMaster.shift, action: .swapMaster)
        add(key: bindings.toggleLayout.key, shift: bindings.toggleLayout.shift, action: .toggleLayout)
        add(key: bindings.toggleFloating.key, shift: bindings.toggleFloating.shift, action: .toggleFloating)
        add(key: bindings.toggleBar.key, shift: bindings.toggleBar.shift, action: .toggleBar)
        add(key: bindings.spawnTerminal.key, shift: bindings.spawnTerminal.shift, action: .spawnTerminal)
        add(key: bindings.decreaseMaster.key, shift: bindings.decreaseMaster.shift, action: .decreaseMaster)
        add(key: bindings.increaseMaster.key, shift: bindings.increaseMaster.shift, action: .increaseMaster)
        add(key: bindings.focusMonitorPrev.key, shift: bindings.focusMonitorPrev.shift, action: .focusMonitor(-1))
        add(key: bindings.focusMonitorNext.key, shift: bindings.focusMonitorNext.shift, action: .focusMonitor(1))
        add(key: bindings.moveMonitorPrev.key, shift: bindings.moveMonitorPrev.shift, action: .moveWindowToMonitor(-1))
        add(key: bindings.moveMonitorNext.key, shift: bindings.moveMonitorNext.shift, action: .moveWindowToMonitor(1))
        add(key: bindings.lastWorkspace.key, shift: bindings.lastWorkspace.shift, action: .switchToLastWorkspace)
        add(key: bindings.reloadConfig.key, shift: bindings.reloadConfig.shift, action: .reloadConfig)
        add(key: bindings.renameWorkspace.key, shift: bindings.renameWorkspace.shift, action: .renameWorkspace)

        return HotkeyPlan(registrations: registrations, skipped: skipped)
    }

    private static func isReserved(_ chord: HotkeyChord) -> Bool {
        chord.modifier == .command && chord.key == Key.tab
    }
}
