import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

func fail(_ message: String) -> Never {
    fputs("dwm-smoke: \(message)\n", stderr)
    exit(1)
}

func attr(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

func cgRect(from value: AnyObject?) -> CGRect? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var rect = CGRect.zero
    guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
    return rect
}

func pointValue(_ point: CGPoint) -> AXValue? {
    var p = point
    return AXValueCreate(.cgPoint, &p)
}

func sizeValue(_ size: CGSize) -> AXValue? {
    var s = size
    return AXValueCreate(.cgSize, &s)
}

struct Win: CustomStringConvertible {
    var pid: pid_t
    var title: String
    var frame: CGRect
    var app: String

    var description: String {
        let t = title.isEmpty ? "(untitled)" : title
        return
            "\(app) | \(t) | \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
    }
}

func standardWindows() -> [Win] {
    var result: [Win] = []
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        if app.bundleIdentifier == "com.parket.app" { continue }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = attr(appEl, kAXWindowsAttribute as String) as? [AXUIElement] else { continue }
        for window in windows {
            let role = attr(window, kAXRoleAttribute as String) as? String ?? ""
            let subrole = attr(window, kAXSubroleAttribute as String) as? String ?? ""
            let minimized = attr(window, kAXMinimizedAttribute as String) as? Bool ?? false
            guard role == kAXWindowRole as String,
                subrole == kAXStandardWindowSubrole as String,
                !minimized
            else { continue }
            guard let pos = attr(window, kAXPositionAttribute as String),
                let size = attr(window, kAXSizeAttribute as String),
                CFGetTypeID(pos) == AXValueGetTypeID(),
                CFGetTypeID(size) == AXValueGetTypeID()
            else { continue }
            var origin = CGPoint.zero
            var sz = CGSize.zero
            guard AXValueGetValue(pos as! AXValue, .cgPoint, &origin),
                AXValueGetValue(size as! AXValue, .cgSize, &sz)
            else { continue }
            let title = attr(window, kAXTitleAttribute as String) as? String ?? ""
            result.append(
                Win(
                    pid: app.processIdentifier,
                    title: title,
                    frame: CGRect(origin: origin, size: sz),
                    app: app.localizedName ?? app.bundleIdentifier ?? "app"
                )
            )
        }
    }
    return result
}

func focusedTitle() -> String? {
    guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
    let appEl = AXUIElementCreateApplication(front.processIdentifier)
    for key in [kAXFocusedWindowAttribute as String, kAXMainWindowAttribute as String] {
        guard let value = attr(appEl, key), CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
        let window = value as! AXUIElement
        return attr(window, kAXTitleAttribute as String) as? String ?? ""
    }
    return nil
}

func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else { fail("could not create key event") }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(3_000)
    up.post(tap: .cghidEventTap)
}

let option: CGEventFlags = [.maskAlternate]
let keys: [String: CGKeyCode] = [
    "j": 38,
    "k": 40,
    "m": 46,
    "f": 3,
    "1": 18,
]

func near(_ a: CGRect, _ b: CGRect, tol: CGFloat = 8) -> Bool {
    abs(a.minX - b.minX) <= tol
        && abs(a.minY - b.minY) <= tol
        && abs(a.width - b.width) <= tol
        && abs(a.height - b.height) <= tol
}

func onscreen(_ frame: CGRect) -> Bool {
    NSScreen.screens.contains { $0.frame.intersects(frame.insetBy(dx: 2, dy: 2)) }
}

func dump(_ label: String) {
    let wins = standardWindows().filter { onscreen($0.frame) }
    print("== \(label) ==")
    print("focused: \(focusedTitle() ?? "nil") frontmost: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
    print("onscreen_standard: \(wins.count)")
    for win in wins.prefix(12) {
        print("  \(win)")
    }
    if wins.count > 1 {
        let groups = Dictionary(grouping: wins) { "\(Int($0.frame.width))x\(Int($0.frame.height))@\(Int($0.frame.minX)),\(Int($0.frame.minY))" }
        let stacked = groups.values.filter { $0.count > 1 }
        if let biggest = stacked.max(by: { $0.count < $1.count }) {
            print("largest_same_frame_stack: \(biggest.count) @ \(Int(biggest[0].frame.width))x\(Int(biggest[0].frame.height))")
        } else {
            print("largest_same_frame_stack: 1")
        }
    }
}

guard AXIsProcessTrusted() else {
    fail("Accessibility required for Terminal/Cursor")
}

let args = Array(CommandLine.arguments.dropFirst())
let mode = args.first ?? "report"

switch mode {
case "report":
    dump("report")
case "chord":
    guard args.count >= 2, let code = keys[args[1]] else {
        fail("usage: dwm-smoke.swift chord j|k|m|f|1")
    }
    let before = focusedTitle()
    postKey(code, flags: option)
    usleep(220_000)
    let after = focusedTitle()
    dump("after option+\(args[1])")
    print("focus_before: \(before ?? "nil")")
    print("focus_after: \(after ?? "nil")")
    if args[1] == "j" || args[1] == "k" {
        if before == after {
            fputs("dwm-smoke: WARN focus did not change for option+\(args[1])\n", stderr)
            exit(2)
        }
    }
case "cycle-focus":
    let rounds = Int(args.dropFirst().first ?? "4") ?? 4
    var titles: [String] = []
    dump("start")
    for i in 0..<rounds {
        postKey(keys["j"]!, flags: option)
        usleep(250_000)
        let title = focusedTitle() ?? "nil"
        titles.append(title)
        print("cycle[\(i)]: \(title)")
    }
    dump("end")
    let unique = Set(titles)
    print("unique_focus_titles: \(unique.count)/\(rounds)")
    if unique.count < 2 {
        fputs("dwm-smoke: FAIL focus cycle stuck on one window\n", stderr)
        exit(2)
    }
    print("dwm-smoke: PASS focus cycle moved between windows")
case "monocle-check":
    postKey(keys["m"]!, flags: option)
    usleep(350_000)
    dump("after toggle layout")
    let wins = standardWindows().filter { onscreen($0.frame) && $0.frame.width > 400 && $0.frame.height > 300 }
    guard let screen = NSScreen.main?.visibleFrame else { fail("no screen") }
    let fullish = wins.filter {
        $0.frame.width >= screen.width * 0.7 && $0.frame.height >= screen.height * 0.7
    }
    print("large_onscreen: \(fullish.count)")
    if fullish.count >= 2 {
        let same = fullish.filter { near($0.frame, fullish[0].frame, tol: 24) }
        print("monocle_stack_estimate: \(same.count)")
        if same.count >= 2 {
            print("dwm-smoke: PASS monocle-like stack present (\(same.count) windows)")
        } else {
            print("dwm-smoke: INFO multiple large windows but not same frame (maybe tile or mixed)")
        }
    } else {
        print("dwm-smoke: INFO not enough large windows to judge monocle stack")
    }
default:
    fail("usage: dwm-smoke.swift report|chord <key>|cycle-focus [n]|monocle-check")
}
