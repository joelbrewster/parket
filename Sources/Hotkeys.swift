import Carbon
import Cocoa

package enum HotkeyStatus: String, Equatable {
    case stopped
    case running
    case degraded
}

@MainActor
package final class Hotkeys {
    package static let shared = Hotkeys()

    private static let lock = NSLock()
    private static var bindings: [HotkeyChord: HotkeyAction] = [:]
    private static var modifier: HotkeyModifier = .option
    private static var hyper = true

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var secureTimer: Timer?
    private var secureInputWasEnabled = false

    package private(set) var status: HotkeyStatus = .stopped
    package private(set) var skippedBindings: [SkippedHotkey] = []
    package private(set) var failedRegistrations: [FailedHotkeyRegistration] = []
    package private(set) var handlerInstallStatus: Int32?

    package var isRunning: Bool { status != .stopped }
    package var issueCount: Int {
        skippedBindings.count + failedRegistrations.count + (handlerInstallStatus == nil ? 0 : 1)
    }

    private init() {}

    package func start() {
        guard status == .stopped else { return }
        applyPlan()
        watchSecureInput()
    }

    package func reload() {
        applyPlan()
    }

    package func stop() {
        teardownTap()
        publish([:], modifier: .option, hyper: false)
        secureTimer?.invalidate()
        secureTimer = nil
        secureInputWasEnabled = false
        status = .stopped
        skippedBindings = []
        failedRegistrations = []
        handlerInstallStatus = nil
    }

    package func diagnosticLines() -> [String] {
        var lines: [String] = [
            "hotkeys: \(status.rawValue)",
            "hotkey_issue_count: \(issueCount)",
            "hotkey_backend: event_tap",
            "hotkey_hyper: \(Config.shared.hyper ? "on" : "off")",
            "secure_event_input: \(IsSecureEventInputEnabled() ? "on" : "off")",
        ]

        if let handlerInstallStatus {
            lines.append("hotkey_backend_status: \(handlerInstallStatus)")
        }

        for skipped in skippedBindings {
            let kept = skipped.keptLabel.map { " kept=\($0)" } ?? ""
            lines.append(
                "hotkey_skipped: \(skipped.skippedLabel) \(skipped.chord.diagnosticText) reason=\(skipped.reason.rawValue)\(kept)"
            )
        }

        for failure in failedRegistrations {
            lines.append(
                "hotkey_failed: \(failure.label) \(failure.chord.diagnosticText) osstatus=\(failure.osStatus)"
            )
        }

        return lines
    }

    private func applyPlan() {
        let plan = HotkeyPlanner.plan(config: Config.shared)
        skippedBindings = plan.skipped
        failedRegistrations = []
        var next: [HotkeyChord: HotkeyAction] = [:]
        for registration in plan.registrations {
            next[registration.chord] = registration.action
        }
        publish(next, modifier: Config.shared.modifier, hyper: Config.shared.hyper)
        if installTap() {
            handlerInstallStatus = nil
            status = issueCount > 0 || next.isEmpty ? .degraded : .running
        } else {
            handlerInstallStatus = -1
            status = .degraded
        }
    }

    private func publish(_ next: [HotkeyChord: HotkeyAction], modifier: HotkeyModifier, hyper: Bool) {
        Self.lock.lock()
        Self.bindings = next
        Self.modifier = modifier
        Self.hyper = hyper
        Self.lock.unlock()
    }

    private func installTap() -> Bool {
        teardownTap()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: Self.eventMask,
                callback: Self.tapCallback,
                userInfo: nil
            )
        else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        tapSource = source
        return true
    }

    private func teardownTap() {
        if let source = tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        tap = nil
        tapSource = nil
    }

    private func reenableTap() {
        if let tap, CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }
        _ = installTap()
    }

    private func watchSecureInput() {
        guard secureTimer == nil else { return }
        secureInputWasEnabled = IsSecureEventInputEnabled()
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated {
                Hotkeys.shared.checkSecureInput()
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        secureTimer = timer
    }

    private func checkSecureInput() {
        let enabled = IsSecureEventInputEnabled()
        let wasEnabled = secureInputWasEnabled
        secureInputWasEnabled = enabled
        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            reenableTap()
        }
        guard wasEnabled, !enabled else { return }
        _ = installTap()
    }

    private static let eventMask: CGEventMask = {
        let down = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let up = CGEventMask(1 << CGEventType.keyUp.rawValue)
        return down | up
    }()

    private static let tapCallback: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    Hotkeys.shared.reenableTap()
                }
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }
        if WorkspaceNamer.consume(type: type, event: event) {
            return nil
        }
        guard let chord = chord(from: event), let action = binding(for: chord) else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            let startedAt = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    Hotkeys.shared.perform(action, startedAt: startedAt)
                }
            }
        }
        return nil
    }

    private static func chord(from event: CGEvent) -> HotkeyChord? {
        lock.lock()
        let configured = modifier
        let hyperOn = hyper
        lock.unlock()
        let flags = CGEventFlags(
            rawValue: event.flags.rawValue
                | CGEventSource.flagsState(.hidSystemState).rawValue
                | CGEventSource.flagsState(.combinedSessionState).rawValue
        )
        let option = Self.optionDown(flags)
        let control = Self.controlDown(flags)
        let command = Self.commandDown(flags)
        let shift = Self.shiftDown(flags)
        let isHyper = option && control && command
        let isPrimary: Bool
        switch configured {
        case .option:
            isPrimary = option && !control && !command
        case .control:
            isPrimary = control && !option && !command
        case .command:
            isPrimary = command && !option && !control
        }
        guard isPrimary || (hyperOn && isHyper) else { return nil }
        let key = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        return HotkeyChord(modifier: configured, shift: shift, key: key)
    }

    private static func optionDown(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskAlternate) || flags.contains(.init(rawValue: 0x0000_0020))
            || flags.contains(.init(rawValue: 0x0000_0040))
    }

    private static func controlDown(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskControl) || flags.contains(.init(rawValue: 0x0000_0001))
            || flags.contains(.init(rawValue: 0x0000_2000))
    }

    private static func commandDown(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand) || flags.contains(.init(rawValue: 0x0000_0008))
            || flags.contains(.init(rawValue: 0x0000_0010))
    }

    private static func shiftDown(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskShift) || flags.contains(.init(rawValue: 0x0000_0002))
            || flags.contains(.init(rawValue: 0x0000_0004))
    }

    private static func binding(for chord: HotkeyChord) -> HotkeyAction? {
        lock.lock()
        defer { lock.unlock() }
        return bindings[chord]
    }

    private func perform(_ action: HotkeyAction, startedAt: TimeInterval) {
        PerformanceTelemetry.traceAction(
            action.traceName,
            startedAt: startedAt,
            metadata: action.traceMetadata
        ) {
            perform(action)
        }
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case .switchWorkspace(let index):
            WorkspaceManager.shared.switchTo(index)
        case .moveWorkspace(let index):
            WorkspaceManager.shared.moveActiveWindowTo(index)
        case .focusMonitor(let offset):
            WorkspaceManager.shared.focusMonitor(offset: offset)
        case .moveWindowToMonitor(let offset):
            WorkspaceManager.shared.moveWindowToMonitor(offset: offset)
        case .switchToLastWorkspace:
            WorkspaceManager.shared.switchToLast()
        case .focusNext:
            WorkspaceManager.shared.focusNext()
        case .focusPrev:
            WorkspaceManager.shared.focusPrev()
        case .swapMaster:
            WorkspaceManager.shared.swapMaster()
        case .toggleLayout:
            WorkspaceManager.shared.toggleLayout()
        case .toggleFloating:
            WorkspaceManager.shared.toggleFloating()
        case .toggleBar:
            Config.setChrome(bar: !Config.shared.bar, allowHidden: true)
        case .spawnTerminal:
            TerminalLauncher.spawn()
        case .decreaseMaster:
            Config.adjustMasterRatio(-Config.masterRatioStep)
        case .increaseMaster:
            Config.adjustMasterRatio(Config.masterRatioStep)
        case .reloadConfig:
            ParketRuntime.shared.reloadConfig()
        case .renameWorkspace:
            WorkspaceNamer.shared.begin()
        case .customCommand(_, let command):
            run(command)
        }
    }

    private func run(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            try? process.run()
        }
    }
}
