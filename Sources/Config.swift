import Cocoa

package enum HotkeyModifier: String, Equatable {
    case option
    case control
    case command
}

package enum BarHighlight: String, Equatable {
    case fill
    case outline
    case text
}

package enum BarFont: String, Equatable {
    case menubar
    case mono

    func nsFont() -> NSFont {
        let size: CGFloat = 14
        switch self {
        case .menubar:
            return NSFont.menuBarFont(ofSize: size)
        case .mono:
            return NSFont(name: "Yakshaven", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

package struct Binding {
    let key: UInt16
    let shift: Bool
    let command: String

    init(key: UInt16, shift: Bool = false, command: String) {
        self.key = key
        self.shift = shift
        self.command = command
    }
}

package enum Key {
    static let `return`: UInt16 = 36
    static let tab: UInt16 = 48
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51

    static let a: UInt16 = 0
    static let b: UInt16 = 11
    static let c: UInt16 = 8
    static let d: UInt16 = 2
    static let e: UInt16 = 14
    static let f: UInt16 = 3
    static let g: UInt16 = 5
    static let h: UInt16 = 4
    static let i: UInt16 = 34
    static let j: UInt16 = 38
    static let k: UInt16 = 40
    static let l: UInt16 = 37
    static let m: UInt16 = 46
    static let n: UInt16 = 45
    static let o: UInt16 = 31
    static let p: UInt16 = 35
    static let q: UInt16 = 12
    static let r: UInt16 = 15
    static let s: UInt16 = 1
    static let t: UInt16 = 17
    static let u: UInt16 = 32
    static let v: UInt16 = 9
    static let w: UInt16 = 13
    static let x: UInt16 = 7
    static let y: UInt16 = 16
    static let z: UInt16 = 6

    static let zero: UInt16 = 29
    static let one: UInt16 = 18
    static let two: UInt16 = 19
    static let three: UInt16 = 20
    static let four: UInt16 = 21
    static let five: UInt16 = 23
    static let six: UInt16 = 22
    static let seven: UInt16 = 26
    static let eight: UInt16 = 28
    static let nine: UInt16 = 25

    static let minus: UInt16 = 27
    static let equal: UInt16 = 24
    static let leftBracket: UInt16 = 33
    static let rightBracket: UInt16 = 30
    static let semicolon: UInt16 = 41
    static let quote: UInt16 = 39
    static let comma: UInt16 = 43
    static let period: UInt16 = 47
    static let slash: UInt16 = 44
    static let backslash: UInt16 = 42
    static let grave: UInt16 = 50

    static let byName: [String: UInt16] = [
        "return": Key.return, "tab": Key.tab, "space": Key.space,
        "escape": Key.escape, "delete": Key.delete,
        "a": Key.a, "b": Key.b, "c": Key.c, "d": Key.d, "e": Key.e,
        "f": Key.f, "g": Key.g, "h": Key.h, "i": Key.i, "j": Key.j,
        "k": Key.k, "l": Key.l, "m": Key.m, "n": Key.n, "o": Key.o,
        "p": Key.p, "q": Key.q, "r": Key.r, "s": Key.s, "t": Key.t,
        "u": Key.u, "v": Key.v, "w": Key.w, "x": Key.x, "y": Key.y,
        "z": Key.z,
        "0": Key.zero, "1": Key.one, "2": Key.two, "3": Key.three,
        "4": Key.four, "5": Key.five, "6": Key.six, "7": Key.seven,
        "8": Key.eight, "9": Key.nine,
        "minus": Key.minus, "equal": Key.equal,
        "leftbracket": Key.leftBracket, "rightbracket": Key.rightBracket,
        "semicolon": Key.semicolon, "quote": Key.quote,
        "comma": Key.comma, "period": Key.period,
        "slash": Key.slash, "backslash": Key.backslash, "grave": Key.grave,
    ]

    static let namesByCode: [UInt16: String] = [
        Key.return: "return", Key.tab: "tab", Key.space: "space",
        Key.escape: "escape", Key.delete: "delete",
        Key.a: "a", Key.b: "b", Key.c: "c", Key.d: "d", Key.e: "e",
        Key.f: "f", Key.g: "g", Key.h: "h", Key.i: "i", Key.j: "j",
        Key.k: "k", Key.l: "l", Key.m: "m", Key.n: "n", Key.o: "o",
        Key.p: "p", Key.q: "q", Key.r: "r", Key.s: "s", Key.t: "t",
        Key.u: "u", Key.v: "v", Key.w: "w", Key.x: "x", Key.y: "y",
        Key.z: "z",
        Key.zero: "0", Key.one: "1", Key.two: "2", Key.three: "3",
        Key.four: "4", Key.five: "5", Key.six: "6", Key.seven: "7",
        Key.eight: "8", Key.nine: "9",
        Key.minus: "minus", Key.equal: "equal",
        Key.leftBracket: "leftbracket", Key.rightBracket: "rightbracket",
        Key.semicolon: "semicolon", Key.quote: "quote",
        Key.comma: "comma", Key.period: "period",
        Key.slash: "slash", Key.backslash: "backslash", Key.grave: "grave",
    ]

    static let numberKeys: [UInt16] = [
        Key.one, Key.two, Key.three, Key.four, Key.five,
        Key.six, Key.seven, Key.eight, Key.nine, Key.zero,
    ]

    static let letterKeys: [UInt16] = [
        Key.q, Key.w, Key.e, Key.r, Key.t,
        Key.y, Key.u, Key.i, Key.o, Key.p,
    ]

    static func name(for code: UInt16) -> String {
        namesByCode[code] ?? "keycode_\(code)"
    }
}

package struct AppRule: Equatable {
    package let app: String
    package let workspace: Int?
    package let float: Bool

    package var workspaceIndex: Int? {
        guard let workspace else { return nil }
        return workspace - 1
    }

    package func matches(name: String?, bundle: String?, executable: String?) -> Bool {
        let needle = app.lowercased()
        if let name, name.lowercased() == needle { return true }
        if let bundle, bundle.lowercased() == needle { return true }
        if let executable, executable.lowercased() == needle { return true }
        return false
    }
}

package struct BuiltinBindings {
    var focusNext: (key: UInt16, shift: Bool) = (Key.j, false)
    var focusPrev: (key: UInt16, shift: Bool) = (Key.k, false)
    var swapMaster: (key: UInt16, shift: Bool) = (Key.return, false)
    var toggleLayout: (key: UInt16, shift: Bool) = (Key.m, false)
    var toggleFloating: (key: UInt16, shift: Bool) = (Key.f, false)
    var toggleBar: (key: UInt16, shift: Bool) = (Key.b, false)
    var spawnTerminal: (key: UInt16, shift: Bool) = (Key.return, true)
    var decreaseMaster: (key: UInt16, shift: Bool) = (Key.h, false)
    var increaseMaster: (key: UInt16, shift: Bool) = (Key.l, false)
    var focusMonitorPrev: (key: UInt16, shift: Bool) = (Key.comma, false)
    var focusMonitorNext: (key: UInt16, shift: Bool) = (Key.period, false)
    var moveMonitorPrev: (key: UInt16, shift: Bool) = (Key.comma, true)
    var moveMonitorNext: (key: UInt16, shift: Bool) = (Key.period, true)
    var lastWorkspace: (key: UInt16, shift: Bool) = (Key.tab, false)
    var reloadConfig: (key: UInt16, shift: Bool) = (Key.c, true)
    var renameWorkspace: (key: UInt16, shift: Bool) = (Key.n, false)
}

package struct Config {
    package static let defaultWorkspaceCount = 10
    package static let defaultMasterRatio: CGFloat = 0.45
    package static let masterRatioStep: CGFloat = 0.05
    package static let minMasterRatio: CGFloat = 0.1
    package static let maxMasterRatio: CGFloat = 0.9
    @MainActor
    package static var shared = Config()
    @MainActor
    package static var loadedFromFile = false
    package static var path: String {
        NSString("~/.config/parket/config.toml").expandingTildeInPath
    }
    package static var url: URL {
        URL(fileURLWithPath: path)
    }

    package var workspaceCount: Int = defaultWorkspaceCount
    package var masterRatio: CGFloat = defaultMasterRatio
    package var modifier: HotkeyModifier = .option
    package var hyper = true
    package var workspaceLetterKeys = true
    package var focusFollowsMouse = true
    package var bar = true
    package var menuBarIcon = false
    package var barFont: BarFont = .mono
    package var barHighlight: BarHighlight = .text
    package var barTagHighlight: BarHighlight = .text
    package var barGap: CGFloat = 0
    package var borderWidth: CGFloat = 2
    package var borderRadius: CGFloat = 6
    package var terminal = "Ghostty"
    package var desktopOverlay = ""
    package var desktopOverlayMode: DesktopOverlayMode = .center
    package var workspaceNames: [Int: String] = [:]
    package var customBindings: [Binding] = []
    package var rules: [AppRule] = []
    package var bindings = BuiltinBindings()

    package func rule(for pid: pid_t) -> AppRule? {
        let app = NSRunningApplication(processIdentifier: pid)
        return rules.first {
            $0.matches(
                name: app?.localizedName,
                bundle: app?.bundleIdentifier,
                executable: app?.executableURL?.deletingPathExtension().lastPathComponent
            )
        }
    }

    package private(set) var numberKeys: [UInt16: Int] = buildNumberKeys(count: defaultWorkspaceCount)

    private static func buildNumberKeys(count: Int) -> [UInt16: Int] {
        var map: [UInt16: Int] = [:]
        for i in 0..<count { map[Key.numberKeys[i]] = i + 1 }
        return map
    }

    @MainActor
    package static func load() {
        loadedFromFile = false
        seedHomeConfigIfNeeded()
        guard FileManager.default.fileExists(atPath: path) else {
            fputs("parket: no config at \(path)\n", stderr)
            applyUIPreferences()
            return
        }

        guard let data = FileManager.default.contents(atPath: path),
            let text = String(data: data, encoding: .utf8)
        else {
            fputs("parket: failed to read config file\n", stderr)
            applyUIPreferences()
            return
        }

        guard let config = parse(text, report: { fputs("parket: \($0)\n", stderr) }) else {
            applyUIPreferences()
            return
        }
        shared = config
        loadedFromFile = true
        applyUIPreferences()
        fputs("parket: loaded \(path)\n", stderr)
    }

    @MainActor
    private static func seedHomeConfigIfNeeded() {
        guard !FileManager.default.fileExists(atPath: path) else { return }
        let manager = FileManager.default
        var candidates: [URL] = []
        if let bundled = Bundle.main.url(forResource: "config", withExtension: "toml") {
            candidates.append(bundled)
        }
        candidates.append(
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("config.toml")
        )
        for source in candidates {
            guard manager.fileExists(atPath: source.path) else { continue }
            let directory = url.deletingLastPathComponent()
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? manager.copyItem(at: source, to: url)
            if manager.fileExists(atPath: path) {
                fputs("parket: seeded config from \(source.path)\n", stderr)
                return
            }
        }
    }

    package static func parse(_ text: String, report: (String) -> Void = { _ in }) -> Config? {
        let toml: [String: Any]
        do {
            toml = try Toml.parse(text)
        } catch {
            report("config parse error: \(error)")
            return nil
        }

        var config = Config()

        if let count = toml["workspace_count"] as? Int, WorkspaceBounds.isValidCount(count) {
            config.workspaceCount = count
            config.numberKeys = buildNumberKeys(count: count)
        }

        if let ratio = toml["master_ratio"] as? Double, ratio > 0, ratio < 1 {
            config.masterRatio = CGFloat(ratio)
        }

        if let hyper = toml["hyper"] as? Bool {
            config.hyper = hyper
        }

        if let letterKeys = toml["workspace_letter_keys"] as? Bool {
            config.workspaceLetterKeys = letterKeys
        }

        if let followsMouse = toml["focus_follows_mouse"] as? Bool {
            config.focusFollowsMouse = followsMouse
        }

        if let gap = cgFloat(toml["bar_gap"]), gap >= 0, gap <= 64 {
            config.barGap = gap
        }

        if let width = cgFloat(toml["border_width"]), width > 0, width <= 32 {
            config.borderWidth = width
        }

        if let radius = cgFloat(toml["border_radius"]), radius >= 0, radius <= 64 {
            config.borderRadius = radius
        }

        if let bar = toml["bar"] as? Bool {
            config.bar = bar
        }

        if let menuBarIcon = toml["menu_bar_icon"] as? Bool {
            config.menuBarIcon = menuBarIcon
        }

        if let font = toml["bar_font"] as? String {
            switch font {
            case "menubar", "menu":
                config.barFont = .menubar
            case "mono", "monospace":
                config.barFont = .mono
            default:
                report("unknown bar_font '\(font)', using menubar")
            }
        }

        if let highlight = toml["bar_highlight"] as? String {
            if let value = parseHighlight(highlight) {
                config.barHighlight = value
                config.barTagHighlight = value
            } else {
                report("unknown bar_highlight '\(highlight)', using text")
            }
        }

        if let highlight = toml["bar_tag_highlight"] as? String {
            if let value = parseHighlight(highlight) {
                config.barTagHighlight = value
            } else {
                report("unknown bar_tag_highlight '\(highlight)', using \(config.barTagHighlight.rawValue)")
            }
        }

        if let terminal = toml["terminal"] as? String {
            config.terminal = terminal.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let mod = toml["modifier"] as? String {
            switch mod {
            case "option", "alt", "opt":
                config.modifier = .option
            case "control", "ctrl":
                config.modifier = .control
            case "command", "cmd":
                config.modifier = .command
            default:
                report("unknown modifier '\(mod)', using option")
            }
        }

        if let bindings = toml["bindings"] as? [String: Any] {
            applyBinding(bindings, "focus_next", to: &config.bindings.focusNext, report: report)
            applyBinding(bindings, "focus_prev", to: &config.bindings.focusPrev, report: report)
            applyBinding(bindings, "swap_master", to: &config.bindings.swapMaster, report: report)
            applyBinding(bindings, "toggle_layout", to: &config.bindings.toggleLayout, report: report)
            applyBinding(bindings, "toggle_floating", to: &config.bindings.toggleFloating, report: report)
            applyBinding(bindings, "toggle_bar", to: &config.bindings.toggleBar, report: report)
            applyBinding(bindings, "spawn_terminal", to: &config.bindings.spawnTerminal, report: report)
            applyBinding(bindings, "decrease_master", to: &config.bindings.decreaseMaster, report: report)
            applyBinding(bindings, "increase_master", to: &config.bindings.increaseMaster, report: report)
            applyBinding(bindings, "focus_monitor_prev", to: &config.bindings.focusMonitorPrev, report: report)
            applyBinding(bindings, "focus_monitor_next", to: &config.bindings.focusMonitorNext, report: report)
            applyBinding(bindings, "move_monitor_prev", to: &config.bindings.moveMonitorPrev, report: report)
            applyBinding(bindings, "move_monitor_next", to: &config.bindings.moveMonitorNext, report: report)
            applyBinding(bindings, "last_workspace", to: &config.bindings.lastWorkspace, report: report)
            applyBinding(bindings, "reload_config", to: &config.bindings.reloadConfig, report: report)
            applyBinding(bindings, "rename_workspace", to: &config.bindings.renameWorkspace, report: report)
        }

        if let names = toml["workspace_names"] as? [String: Any] {
            for (key, value) in names {
                guard let number = Int(key), number >= 1, number <= config.workspaceCount else { continue }
                let name = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let cleaned = name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
                if !cleaned.isEmpty {
                    config.workspaceNames[number - 1] = String(cleaned.prefix(12))
                }
            }
        }

        if let customs = toml["custom"] as? [[String: Any]] {
            config.customBindings = customs.compactMap { entry in
                guard let keyStr = entry["key"] as? String,
                    let command = entry["command"] as? String
                else { return nil }
                let (keyCode, shift) = parseKeyString(keyStr)
                guard let code = keyCode else {
                    report("unknown key '\(keyStr)' in custom binding")
                    return nil
                }
                return Binding(key: code, shift: shift, command: command)
            }
        }

        if let rows = toml["rules"] as? [[String: Any]] {
            config.rules = rows.compactMap { row in
                parseRule(row, workspaceCount: config.workspaceCount, report: report)
            }
        }

        return config
    }

    @MainActor
    package static func openConfig() {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if !manager.fileExists(atPath: path) {
            try? defaultConfigText.write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    package static func setChrome(bar: Bool? = nil, menuBarIcon: Bool? = nil, allowHidden: Bool = false) {
        var nextBar = bar ?? shared.bar
        var nextIcon = menuBarIcon ?? shared.menuBarIcon
        if !allowHidden && !nextBar && !nextIcon {
            if bar != nil {
                nextIcon = true
            } else {
                nextBar = true
            }
        }
        let barChanged = nextBar != shared.bar
        shared.bar = nextBar
        shared.menuBarIcon = nextIcon
        defaults.set(nextBar, forKey: uiBarKey)
        defaults.set(nextIcon, forKey: uiMenuBarIconKey)
        StatusBar.shared.applyVisibility()
        if barChanged {
            WorkspaceManager.shared.applyChrome()
        } else {
            Bar.shared.sync(screens: NSScreen.screens)
        }
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setBarFont(_ font: BarFont) {
        shared.barFont = font
        defaults.set(font.rawValue, forKey: uiFontKey)
        Bar.shared.update()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setBarHighlight(_ value: BarHighlight) {
        shared.barHighlight = value
        defaults.set(value.rawValue, forKey: uiHighlightKey)
        Bar.shared.update()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setBarTagHighlight(_ value: BarHighlight) {
        shared.barTagHighlight = value
        defaults.set(value.rawValue, forKey: uiTagHighlightKey)
        Bar.shared.update()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setBarGap(_ value: CGFloat) {
        shared.barGap = min(max(value, 0), 64)
        defaults.set(Double(shared.barGap), forKey: uiBarGapKey)
        WorkspaceManager.shared.applyCurrentConfig()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setBorderWidth(_ value: CGFloat) {
        shared.borderWidth = min(max(value, 1), 32)
        defaults.set(Double(shared.borderWidth), forKey: uiBorderWidthKey)
        Bar.shared.update()
        FocusBorder.shared.update()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setBorderRadius(_ value: CGFloat) {
        shared.borderRadius = min(max(value, 0), 64)
        defaults.set(Double(shared.borderRadius), forKey: uiBorderRadiusKey)
        Bar.shared.update()
        FocusBorder.shared.update()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setWorkspaceCount(_ count: Int) {
        guard WorkspaceBounds.isValidCount(count) else { return }
        shared.workspaceCount = count
        shared.numberKeys = buildNumberKeys(count: count)
        defaults.set(count, forKey: uiWorkspaceCountKey)
        WorkspaceManager.shared.applyCurrentConfig()
        Hotkeys.shared.reload()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setMasterRatio(_ value: CGFloat) {
        let next = min(max(value, minMasterRatio), maxMasterRatio)
        shared.masterRatio = next
        defaults.set(Double(next), forKey: uiMasterRatioKey)
        WorkspaceManager.shared.retileNow()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setModifier(_ value: HotkeyModifier) {
        shared.modifier = value
        defaults.set(value.rawValue, forKey: uiModifierKey)
        Hotkeys.shared.reload()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setHyper(_ value: Bool) {
        shared.hyper = value
        defaults.set(value, forKey: uiHyperKey)
        Hotkeys.shared.reload()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setWorkspaceLetterKeys(_ value: Bool) {
        shared.workspaceLetterKeys = value
        defaults.set(value, forKey: uiLetterKeysKey)
        Hotkeys.shared.reload()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setFocusFollowsMouse(_ value: Bool) {
        shared.focusFollowsMouse = value
        defaults.set(value, forKey: uiFocusFollowsMouseKey)
        MouseFocus.shared.apply(enabled: value)
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setTerminal(_ value: String) {
        shared.terminal = value
        defaults.set(value, forKey: uiTerminalKey)
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setDesktopOverlay(_ value: String) {
        shared.desktopOverlay = value
        defaults.set(value, forKey: uiDesktopOverlayKey)
        DesktopOverlay.shared.reload()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func setDesktopOverlayMode(_ value: DesktopOverlayMode) {
        shared.desktopOverlayMode = value
        defaults.set(value.rawValue, forKey: uiDesktopOverlayModeKey)
        DesktopOverlay.shared.reload()
        StatusBar.shared.refresh()
    }

    @MainActor
    package static func applyUIPreferences() {
        if let value = bool(uiBarKey) { shared.bar = value }
        if let value = bool(uiMenuBarIconKey) { shared.menuBarIcon = value }
        if let raw = defaults.string(forKey: uiFontKey) {
            switch raw {
            case "menubar", "menu":
                shared.barFont = .menubar
            case "mono", "monospace":
                shared.barFont = .mono
            default:
                break
            }
        }
        if let raw = defaults.string(forKey: uiHighlightKey), let value = parseHighlight(raw) {
            shared.barHighlight = value
        }
        if let raw = defaults.string(forKey: uiTagHighlightKey), let value = parseHighlight(raw) {
            shared.barTagHighlight = value
        }
        if let value = number(uiBarGapKey), value >= 0, value <= 64 { shared.barGap = value }
        if let value = number(uiBorderWidthKey), value > 0, value <= 32 { shared.borderWidth = value }
        if let value = number(uiBorderRadiusKey), value >= 0, value <= 64 { shared.borderRadius = value }
        if let count = int(uiWorkspaceCountKey), WorkspaceBounds.isValidCount(count) {
            shared.workspaceCount = count
            shared.numberKeys = buildNumberKeys(count: count)
        }
        if let value = number(uiMasterRatioKey), value > 0, value < 1 { shared.masterRatio = value }
        if let raw = defaults.string(forKey: uiModifierKey) {
            switch raw {
            case "option", "alt", "opt":
                shared.modifier = .option
            case "control", "ctrl":
                shared.modifier = .control
            case "command", "cmd":
                shared.modifier = .command
            default:
                break
            }
        }
        if let value = bool(uiHyperKey) { shared.hyper = value }
        if let value = bool(uiLetterKeysKey) { shared.workspaceLetterKeys = value }
        if let value = bool(uiFocusFollowsMouseKey) { shared.focusFollowsMouse = value }
        if defaults.object(forKey: uiTerminalKey) != nil {
            shared.terminal = defaults.string(forKey: uiTerminalKey) ?? ""
        }
        if defaults.object(forKey: uiDesktopOverlayKey) != nil {
            shared.desktopOverlay = defaults.string(forKey: uiDesktopOverlayKey) ?? ""
        }
        if let raw = defaults.string(forKey: uiDesktopOverlayModeKey) {
            switch raw {
            case DesktopOverlayMode.tile.rawValue:
                shared.desktopOverlayMode = .tile
            case DesktopOverlayMode.fill.rawValue:
                shared.desktopOverlayMode = .fill
            default:
                shared.desktopOverlayMode = .center
            }
        }
    }

    private static var defaults: UserDefaults { UserDefaults.standard }

    private static let uiBarKey = "parket.bar"
    private static let uiMenuBarIconKey = "parket.menuBarIcon"
    private static let uiFontKey = "parket.barFont"
    private static let uiHighlightKey = "parket.barHighlight"
    private static let uiTagHighlightKey = "parket.barTagHighlight"
    private static let uiBarGapKey = "parket.barGap"
    private static let uiBorderWidthKey = "parket.borderWidth"
    private static let uiBorderRadiusKey = "parket.borderRadius"
    private static let uiWorkspaceCountKey = "parket.workspaceCount"
    private static let uiMasterRatioKey = "parket.masterRatio"
    private static let uiModifierKey = "parket.modifier"
    private static let uiHyperKey = "parket.hyper"
    private static let uiLetterKeysKey = "parket.letterKeys"
    private static let uiFocusFollowsMouseKey = "parket.focusFollowsMouse"
    private static let uiTerminalKey = "parket.terminal"
    private static let uiDesktopOverlayKey = "parket.desktopOverlay"
    private static let uiDesktopOverlayModeKey = "parket.desktopOverlayMode"

    private static func bool(_ key: String) -> Bool? {
        defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key)
    }

    private static func int(_ key: String) -> Int? {
        defaults.object(forKey: key) == nil ? nil : defaults.integer(forKey: key)
    }

    private static func number(_ key: String) -> CGFloat? {
        defaults.object(forKey: key) == nil ? nil : CGFloat(defaults.double(forKey: key))
    }

    @MainActor
    package static func setWorkspaceName(_ index: Int, _ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let clipped = String(cleaned.prefix(12))
        if clipped.isEmpty {
            shared.workspaceNames.removeValue(forKey: index)
        } else {
            shared.workspaceNames[index] = clipped
        }
        writeWorkspaceNames()
    }

    @MainActor
    package static func adjustMasterRatio(_ delta: CGFloat) {
        let stepped = ((shared.masterRatio + delta) * 100).rounded() / 100
        let next = min(max(stepped, minMasterRatio), maxMasterRatio)
        guard abs(next - shared.masterRatio) > 0.0001 else { return }
        shared.masterRatio = next
        defaults.set(Double(next), forKey: uiMasterRatioKey)
        WorkspaceManager.shared.retileNow()
        StatusBar.shared.refresh()
    }

    private static func upsertBool(_ key: String, _ value: Bool) {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? defaultConfigText
        let line = "\(key) = \(value ? "true" : "false")"
        let pattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*(true|false)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
            regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
        {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: line
            )
        } else {
            text = line + "\n" + text
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func upsertNumber(_ key: String, _ value: CGFloat) {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? defaultConfigText
        let line = "\(key) = \(String(format: "%.2f", value))"
        let pattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*[0-9.]+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
            regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
        {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: line
            )
        } else {
            text = line + "\n" + text
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func upsertString(_ key: String, _ value: String) {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? defaultConfigText
        let line = "\(key) = \"\(value)\""
        let pattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*\".*\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
            regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
        {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: line
            )
        } else {
            text = line + "\n" + text
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func parseRule(
        _ row: [String: Any],
        workspaceCount: Int,
        report: (String) -> Void
    ) -> AppRule? {
        guard let app = row["app"] as? String else {
            report("rule missing app")
            return nil
        }
        let name = app.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            report("rule missing app")
            return nil
        }
        var workspace: Int?
        if let value = row["workspace"] as? Int {
            if WorkspaceBounds.isValidIndex(value - 1, count: workspaceCount) {
                workspace = value
            } else {
                report("rule workspace \(value) out of range for '\(name)'")
            }
        }
        let float = row["float"] as? Bool ?? false
        guard workspace != nil || float else {
            report("rule for '\(name)' needs workspace or float")
            return nil
        }
        return AppRule(app: name, workspace: workspace, float: float)
    }

    private static func cgFloat(_ value: Any?) -> CGFloat? {
        if let value = value as? Double { return CGFloat(value) }
        if let value = value as? Int { return CGFloat(value) }
        return nil
    }

    private static func parseHighlight(_ value: String) -> BarHighlight? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fill", "solid":
            return .fill
        case "outline", "border", "stroke":
            return .outline
        case "text", "color", "accent":
            return .text
        default:
            return nil
        }
    }

    private static func parseKeyString(_ s: String) -> (key: UInt16?, shift: Bool) {
        if s.hasPrefix("shift+") {
            let name = String(s.dropFirst(6))
            return (Key.byName[name], true)
        }
        return (Key.byName[s], false)
    }

    private static func applyBinding(
        _ dict: [String: Any], _ name: String,
        to binding: inout (key: UInt16, shift: Bool),
        report: (String) -> Void
    ) {
        guard let value = dict[name] as? String else { return }
        let (keyCode, shift) = parseKeyString(value)
        guard let code = keyCode else {
            report("unknown key '\(value)' for binding '\(name)'")
            return
        }
        binding = (code, shift)
    }

    private static var defaultConfigText: String {
        """
        workspace_count = 10
        master_ratio = 0.45
        modifier = "option"
        hyper = true
        workspace_letter_keys = true
        focus_follows_mouse = true
        bar = true
        menu_bar_icon = false
        bar_font = "mono"
        bar_highlight = "text"
        bar_tag_highlight = "text"
        bar_gap = 0
        border_width = 2
        border_radius = 6
        terminal = "Ghostty"

        [bindings]
        focus_next = "j"
        focus_prev = "k"
        swap_master = "return"
        toggle_layout = "m"
        toggle_floating = "f"
        toggle_bar = "b"
        spawn_terminal = "shift+return"
        decrease_master = "h"
        increase_master = "l"
        focus_monitor_prev = "comma"
        focus_monitor_next = "period"
        move_monitor_prev = "shift+comma"
        move_monitor_next = "shift+period"
        last_workspace = "tab"
        reload_config = "shift+c"
        rename_workspace = "n"
        """
    }

    @MainActor
    private static func writeWorkspaceNames() {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? defaultConfigText
        text = stripSection(text, named: "workspace_names")
        let rows = shared.workspaceNames.keys.sorted().compactMap { index -> String? in
            guard let name = shared.workspaceNames[index], !name.isEmpty else { return nil }
            return "\(index + 1) = \"\(name)\""
        }
        if !rows.isEmpty {
            if !text.hasSuffix("\n") { text += "\n" }
            text += "\n[workspace_names]\n" + rows.joined(separator: "\n") + "\n"
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func stripSection(_ text: String, named name: String) -> String {
        var result: [String] = []
        var skipping = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let header = line.prefix(while: { $0 != "#" }).trimmingCharacters(in: .whitespaces)
            if header.hasPrefix("["), header.hasSuffix("]") {
                skipping = header == "[\(name)]"
            }
            if skipping { continue }
            result.append(String(line))
        }
        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            result.removeLast()
        }
        return result.joined(separator: "\n")
    }
}
