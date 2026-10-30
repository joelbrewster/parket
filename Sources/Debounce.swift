import Foundation

@MainActor
final class Debounce {
    private var work: DispatchWorkItem?

    var isPending: Bool { work != nil }

    func schedule(after delay: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.work = nil
                block()
            }
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        work?.cancel()
        work = nil
    }
}

@MainActor
final class DebounceMap<Key: Hashable> {
    private var works: [Key: DispatchWorkItem] = [:]

    func schedule(_ key: Key, after delay: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        cancel(key)
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.works.removeValue(forKey: key)
                block()
            }
        }
        works[key] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel(_ key: Key) {
        works.removeValue(forKey: key)?.cancel()
    }

    func cancelAll() {
        for work in works.values {
            work.cancel()
        }
        works.removeAll()
    }
}
