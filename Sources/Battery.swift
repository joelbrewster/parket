import Foundation
import IOKit.ps

@MainActor
package final class Battery {
    package static let shared = Battery()

    package private(set) var text = ""

    private var timer: Timer?
    private var source: CFRunLoopSource?

    private init() {}

    package func start() {
        guard timer == nil else { return }
        refresh()
        if let src = IOPSNotificationCreateRunLoopSource(batteryPowerChanged, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
            source = src
        }
        let timer = Timer(timeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated {
                Battery.shared.refresh()
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    fileprivate func refresh() {
        let next = BatteryInfo.percentage().flatMap { $0 < 100 ? "\($0)%" : nil } ?? ""
        guard next != text else { return }
        text = next
        Bar.shared.update()
    }
}

private func batteryPowerChanged(_ context: UnsafeMutableRawPointer?) {
    Task { @MainActor in
        Battery.shared.refresh()
    }
}

private enum BatteryInfo {
    static func percentage() -> Int? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard
                let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any]
            else { continue }
            guard string(desc, kIOPSTypeKey) == kIOPSInternalBatteryType else { continue }
            let capacity = number(desc, kIOPSCurrentCapacityKey)
            let max = number(desc, kIOPSMaxCapacityKey)
            guard let capacity, let max, max > 0 else { return nil }
            return Int((Double(capacity) / Double(max) * 100).rounded())
        }
        return nil
    }

    private static func string(_ desc: [String: Any], _ key: String) -> String? {
        desc[key] as? String
    }

    private static func number(_ desc: [String: Any], _ key: String) -> Int? {
        if let value = desc[key] as? Int { return value }
        if let value = desc[key] as? NSNumber { return value.intValue }
        return nil
    }
}
