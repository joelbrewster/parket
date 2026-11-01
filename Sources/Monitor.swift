import AppKit

enum WindowUpdate {
    case missing
    case inserted
    case replaced
    case unchanged
}

@MainActor
package final class Monitor {
    private static let retileDelay: TimeInterval = 0.05
    private static let geometrySuppressionDelay: TimeInterval = 0.16
    private static let frameTolerance: CGFloat = 2.0
    private static let windowSettleStepDelay: TimeInterval = 0.08
    private static let windowSettleMaxSteps = 8

    let displayID: CGDirectDisplayID
    var screen: NSScreen
    var tileFrame: CGRect
    private let offscreenContext: OffscreenWindowPlacementContext
    var workspaces: [[TrackedWindow]] = Array(repeating: [], count: Config.shared.workspaceCount)
    var layouts: [Layout] = Array(repeating: .initial, count: Config.shared.workspaceCount)
    var focusedIndices: [Int] = Array(repeating: 0, count: Config.shared.workspaceCount)
    private var floating: Set<WindowGroupKey> = []
    private var floatingFrames: [WindowGroupKey: CGRect] = [:]
    var active: Int = 0
    var previousActive: Int = 0
    private let retileDebounce = Debounce()
    private var ignoreGeometryUntil: TimeInterval = 0
    private var geometryOperationGeneration: UInt64 = 0
    private var focusRestoreGeneration: UInt64 = 0
    private var moveFocusGeneration: UInt64 = 0

    init(
        displayID: CGDirectDisplayID,
        screen: NSScreen,
        tileFrame: CGRect,
        offscreenContext: OffscreenWindowPlacementContext
    ) {
        self.displayID = displayID
        self.screen = screen
        self.tileFrame = tileFrame
        self.offscreenContext = offscreenContext
        self.layouts = WorkspaceLayoutStore.load(
            displayID: displayID, count: Config.shared.workspaceCount)
    }

    func switchTo(_ index: Int) {
        guard !WorkspaceManager.shared.isTilingPaused else { return }
        guard index >= 0, index < Config.shared.workspaceCount, index != active else { return }

        PerformanceTelemetry.measure(.workspaceSwitch) {
            let previous = active
            previousActive = previous
            active = index

            suppressGeometryNotifications()
            PerformanceTelemetry.traceSubspan("retile") {
                retile(validate: false)
            }
            PerformanceTelemetry.traceSubspan("hide") {
                PerformanceTelemetry.measure(.hideWorkspace) {
                    for win in workspaces[previous] {
                        hideOffscreen(win)
                    }
                }
            }
            PerformanceTelemetry.traceSubspan("focus") {
                if activeWorkspaceHasMultipleProcesses() {
                    PerformanceTelemetry.measure(.focusRestore) {
                        restoreFocusedWindow(afterWorkspaceSwitch: true)
                    }
                } else {
                    scheduleFocusedWindowRestore(activeWorkspace: index)
                }
            }
        }
    }

    func revealWorkspace(_ index: Int, focusing focused: TrackedWindow) {
        guard !WorkspaceManager.shared.isTilingPaused else { return }
        guard index >= 0, index < Config.shared.workspaceCount else { return }

        if index != active {
            let previous = active
            previousActive = previous
            active = index

            suppressGeometryNotifications()
            PerformanceTelemetry.measure(.hideWorkspace) {
                for win in workspaces[previous] {
                    hideOffscreen(win)
                }
            }
        }

        guard rememberFocusedWindow(focused) else { return }
        retile(validate: false)
        guard rememberFocusedWindow(focused) else { return }

        let target = workspaces[active][focusedIndices[active]]
        PerformanceTelemetry.measure(.focusRestore) {
            target.focus()
        }
    }

    @discardableResult
    func moveActiveWindowTo(_ index: Int) -> TrackedWindow? {
        guard !WorkspaceManager.shared.isTilingPaused else { return nil }
        guard index >= 0, index < Config.shared.workspaceCount, index != active else { return nil }
        guard let focused = WindowManager.focusedWindow() else { return nil }

        guard let i = workspaces[active].firstIndex(of: focused) else { return nil }
        let moved = focused.keepingMembers(from: workspaces[active][i])
        workspaces[active].remove(at: i)
        workspaces[index].insert(moved, at: 0)

        retile(validate: false)
        hideOffscreen(moved)
        WindowManager.invalidateAppliedGeometry(moved)

        let next = workspaces[active].first(where: { $0.pid == moved.pid }) ?? workspaces[active].first
        if let next {
            focusAfterWindowRemoval(next)
        }
        return moved
    }

    func tiledWindow(at point: CGPoint) -> TrackedWindow? {
        guard tileFrame.contains(point), workspaces.indices.contains(active) else { return nil }
        let windows = workspaces[active]
        for window in windows where isFloating(window) {
            if let frame = window.getFrame(), frame.contains(point) {
                return window
            }
        }
        let tiled = windows.filter { !isFloating($0) }
        if layouts[active] == .monocle {
            if windows.indices.contains(focusedIndices[active]) {
                let focused = windows[focusedIndices[active]]
                if !isFloating(focused) { return focused }
            }
            return tiled.first
        }
        let plan = currentArrangePlan(tiled: tiled)
        for (slot, tiledIndex) in plan.visibleTiledIndices.enumerated() {
            if plan.tiledFrames[slot].contains(point) {
                return tiled[tiledIndex]
            }
        }
        return nil
    }

    @discardableResult
    func insertWindow(_ window: TrackedWindow) -> Bool {
        guard updateExistingWindow(window) == .missing else { return false }
        workspaces[active].insert(window, at: 0)
        return true
    }

    @discardableResult
    func addWindow(_ window: TrackedWindow) -> WindowUpdate {
        addWindow(window, workspaceIndex: active)
    }

    @discardableResult
    func addWindow(_ window: TrackedWindow, workspaceIndex: Int) -> WindowUpdate {
        let existing = updateExistingWindow(window)
        guard existing == .missing else { return existing }
        let target = workspaces.indices.contains(workspaceIndex) ? workspaceIndex : active
        workspaces[target].insert(window, at: 0)
        if target == active {
            scheduleRetile()
        } else if !WorkspaceManager.shared.isTilingPaused {
            hideOffscreen(window)
            WindowManager.invalidateAppliedGeometry(window)
        }
        return .inserted
    }

    func adoptWindowFromRemovedMonitor(
        _ window: TrackedWindow,
        sourceWorkspaceIndex: Int,
        sourceActive: Int,
        wasFloating: Bool = false,
        floatingFrame: CGRect? = nil
    ) {
        let target = RemovedMonitorWindowMigration.targetWorkspace(
            sourceWorkspaceIndex: sourceWorkspaceIndex,
            sourceActive: sourceActive,
            targetActive: active,
            workspaceCount: workspaces.count
        )
        guard updateExistingWindow(window) == .missing else { return }
        workspaces[target].insert(window, at: 0)
        if wasFloating {
            floating.insert(window.group)
            if let floatingFrame {
                floatingFrames[window.group] = floatingFrame
            }
        }
        if target != active, !WorkspaceManager.shared.isTilingPaused {
            hideOffscreen(window)
            WindowManager.invalidateAppliedGeometry(window)
        }
    }

    func floatingFrame(for window: TrackedWindow) -> CGRect? {
        floatingFrames[window.group]
    }

    func restoreFloatingFrame(_ window: TrackedWindow, _ frame: CGRect) {
        guard isFloating(window) else { return }
        floatingFrames[window.group] = frame
    }

    func updateExistingWindow(_ window: TrackedWindow) -> WindowUpdate {
        for ws in 0..<workspaces.count {
            guard let i = workspaces[ws].firstIndex(of: window) else { continue }
            let current = workspaces[ws][i]
            if current.hasElement(window) {
                if current.group != window.group || !current.hasSameMembers(window) {
                    workspaces[ws][i] = window
                    return .replaced
                }
                return .unchanged
            }
            if current.isTileable() {
                if current.group == window.group && !current.hasSameMembers(window) {
                    workspaces[ws][i] = window
                    return .replaced
                }
                return .unchanged
            }
            workspaces[ws][i] = window
            return .replaced
        }
        return .missing
    }

    func removeWindows(where predicate: (TrackedWindow) -> Bool) -> Bool {
        var needsRetile = false
        var changed = false
        for i in 0..<Config.shared.workspaceCount {
            let before = workspaces[i].count
            workspaces[i].removeAll(where: predicate)
            if workspaces[i].count != before {
                changed = true
                needsRetile = needsRetile || (i == active)
            }
        }
        if changed && needsRetile { scheduleRetile() }
        return changed
    }

    func removeStaleWindows(pid: pid_t, unmatchedCurrent: inout [TrackedWindow]) -> Bool {
        removeWindows { window in
            window.pid == pid
                && WindowSnapshotReconciliation.isStale(
                    window,
                    unmatchedCurrent: &unmatchedCurrent
                )
        }
    }

    func restoreFocusAfterClosedWindow(removedWindowIndex: Int) -> TrackedWindow? {
        let windows = workspaces[active]
        guard
            let targetIndex = ClosedWindowFocusRepair.targetIndex(
                removedWindowIndex: removedWindowIndex,
                remainingCount: windows.count
            )
        else { return nil }
        focusedIndices[active] = targetIndex
        let target = windows[targetIndex]
        focusAfterWindowRemoval(target)
        restack(raiseAboveFloaters: layouts[active] == .monocle && !isFloating(target))
        return target
    }

    func containsWindow(_ window: TrackedWindow) -> Bool {
        workspaces.contains { $0.contains(window) }
    }

    func placedFrame(for window: TrackedWindow) -> CGRect? {
        if isFloating(window) { return nil }
        let tiled = nextTiled()
        guard let tiledIndex = tiled.firstIndex(of: window) else { return nil }
        let plan = currentArrangePlan(tiled: tiled)
        guard let visibleSlot = plan.visibleTiledIndices.firstIndex(of: tiledIndex),
            plan.tiledFrames.indices.contains(visibleSlot)
        else { return nil }
        return plan.tiledFrames[visibleSlot]
    }

    func focusNext() { focusOffset(1) }
    func focusPrev() { focusOffset(-1) }

    private func focusOffset(_ offset: Int) {
        let windows = workspaces[active]
        let focusedIndex = WindowManager.focusedWindow().flatMap { windows.firstIndex(of: $0) }
        guard
            let currentIndex = WorkspaceFocusCycle.resolveCurrentIndex(
                focusedIndex: focusedIndex,
                savedIndex: focusedIndices[active],
                count: windows.count
            ),
            let targetIndex = WorkspaceFocusCycle.targetIndex(
                current: currentIndex,
                offset: offset,
                count: windows.count
            )
        else { return }
        let target = windows[targetIndex]
        let tiledBefore = nextTiled()
        let visibleBefore = currentArrangePlan(tiled: tiledBefore).visibleTiledIndices
        focusedIndices[active] = targetIndex
        let tiledAfter = nextTiled()
        let visibleAfter = currentArrangePlan(tiled: tiledAfter).visibleTiledIndices
        if layouts[active] == .tile, visibleBefore != visibleAfter {
            retile(validate: false)
        } else {
            restack()
        }
        target.focus()
    }

    func swapMaster() {
        guard !WorkspaceManager.shared.isTilingPaused else { return }
        let tiled = nextTiled()
        guard tiled.count > 1 else { return }
        let focused = selectedWindow()
        guard let focused, !isFloating(focused),
            let focusIndex = workspaces[active].firstIndex(of: focused),
            let masterIndex = workspaces[active].firstIndex(of: tiled[0]),
            focusIndex != masterIndex
        else { return }
        workspaces[active].swapAt(masterIndex, focusIndex)
        focusedIndices[active] = masterIndex
        retile(validate: false)
        workspaces[active][masterIndex].focus()
    }

    func toggleLayout() {
        guard !WorkspaceManager.shared.isTilingPaused else { return }
        layouts[active] = layouts[active] == .tile ? .monocle : .tile
        persistLayouts()
        retile(force: true, validate: false)
        let expectedLayout = layouts[active]
        let generation = geometryOperationGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            guard geometryOperationGeneration == generation else { return }
            guard layouts[active] == expectedLayout else { return }
            retile(force: true, validate: false)
        }
    }

    func isFloating(_ window: TrackedWindow) -> Bool {
        floating.contains(window.group)
    }

    func setFloating(_ window: TrackedWindow, _ isFloating: Bool) {
        if isFloating {
            floating.insert(window.group)
            rememberFloatingFrame(window)
        } else {
            floating.remove(window.group)
            floatingFrames.removeValue(forKey: window.group)
        }
    }

    func rememberFloatingFrame(_ window: TrackedWindow) {
        guard isFloating(window), let ax = window.getFrame() else { return }
        let frame = ScreenGeometry.convertRect(ax, screens: WindowManager.screenDescriptors())
        guard frame.intersects(tileFrame.insetBy(dx: -40, dy: -40)) else { return }
        floatingFrames[window.group] = ax
    }

    var focusedWindowIsFloating: Bool {
        guard let focused = WindowManager.focusedWindow() else { return false }
        return workspaces[active].contains(focused) && isFloating(focused)
    }

    func toggleFloating() {
        guard !WorkspaceManager.shared.isTilingPaused else { return }
        guard let window = selectedWindow(),
            let index = workspaces[active].firstIndex(of: window)
        else { return }
        focusedIndices[active] = index
        setFloating(window, !isFloating(window))
        retile(validate: false)
        window.focus()
    }

    private func scheduleRetile() {
        enqueueRetile(corrective: false)
    }

    func scheduleCorrectiveRetile() {
        guard !shouldSuppressGeometryNotification() else { return }
        enqueueRetile(corrective: true)
    }

    private func enqueueRetile(corrective: Bool) {
        guard !WorkspaceManager.shared.isTilingPaused else { return }
        let scheduledActive = active
        let scheduledGeneration = geometryOperationGeneration
        retileDebounce.schedule(after: Self.retileDelay) { [self] in
            guard active == scheduledActive else { return }
            guard geometryOperationGeneration == scheduledGeneration else { return }
            if corrective {
                guard ProcessInfo.processInfo.systemUptime >= ignoreGeometryUntil else { return }
                guard !activeWorkspaceMatchesLayout(tolerance: Self.frameTolerance) else { return }
                invalidateActiveWorkspaceAppliedGeometry()
            }
            retile(validate: false)
        }
    }

    func shouldSuppressGeometryNotification() -> Bool {
        guard ProcessInfo.processInfo.systemUptime < ignoreGeometryUntil else { return false }
        PerformanceTelemetry.recordSuppressedGeometryNotification()
        return true
    }

    @discardableResult
    func retile(force: Bool = false, validate: Bool = true) -> CGRect {
        guard force || !WorkspaceManager.shared.isTilingPaused else { return tileFrame }
        return PerformanceTelemetry.measure(.retile) {
            arrange(validate: validate, force: force)
        }
    }

    private func arrange(validate: Bool, force: Bool) -> CGRect {
        deduplicateActiveWorkspace()
        if validate {
            cleanActiveWorkspace()
        }
        if force || validate {
            invalidateActiveWorkspaceAppliedGeometry()
        }
        suppressGeometryNotifications()
        extendGeometrySuppression(
            by: Double(Self.windowSettleMaxSteps) * Self.windowSettleStepDelay
                + Self.geometrySuppressionDelay
        )
        pruneFloating()
        let tiled = nextTiled()
        let plan = currentArrangePlan(tiled: tiled)
        for index in tiled.indices {
            WindowManager.invalidateAppliedGeometry(tiled[index])
            if let slot = plan.visibleTiledIndices.firstIndex(of: index) {
                tiled[index].setFrame(plan.tiledFrames[slot])
            } else {
                hideOffscreen(tiled[index])
            }
        }
        for window in workspaces[active] where isFloating(window) {
            if let frame = floatingFrames[window.group] {
                window.setFrame(frame)
            }
        }
        for (slot, tiledIndex) in plan.visibleTiledIndices.enumerated() {
            scheduleWindowSettle(
                window: tiled[tiledIndex],
                target: plan.tiledFrames[slot],
                step: 0,
                generation: geometryOperationGeneration,
                previousAttempt: nil
            )
        }
        restack(raiseAboveFloaters: plan.raiseSelectedAboveFloaters)
        FocusBorder.shared.concealUntilSettled()
        return tileFrame
    }

    private func currentArrangePlan(tiled: [TrackedWindow]) -> ArrangePlan {
        let selected = selectedWindow()
        let focusedTiledIndex = selected.flatMap { tiled.firstIndex(of: $0) }
        return ArrangePlanner.plan(
            tileFrame: tileFrame,
            layout: layouts[active],
            tiledCount: tiled.count,
            focusedTiledIndex: focusedTiledIndex,
            selectedIsTiled: selected.map { !isFloating($0) } ?? false,
            floatingCount: workspaces[active].filter { isFloating($0) }.count,
            masterRatio: Config.shared.masterRatio,
            gap: Config.shared.windowGap
        )
    }

    func restack(raiseAboveFloaters: Bool = false) {
        _ = raiseAboveFloaters
        selectedWindow()?.raise()
    }

    func cancelPendingRetile() {
        retileDebounce.cancel()
        ignoreGeometryUntil = 0
        geometryOperationGeneration &+= 1
    }

    func applyScreenChangeGeometry() {
        retile(validate: true)
        hideInactiveWorkspaces()
    }

    func applyResumeGeometry() {
        retile(force: true)
        hideInactiveWorkspaces()
    }

    private func hideInactiveWorkspaces() {
        for workspaceIndex in ScreenChangeVisibilityPlan.hiddenWorkspaceIndices(
            workspaceCount: workspaces.count,
            active: active
        ) {
            for window in workspaces[workspaceIndex] {
                WindowManager.invalidateAppliedGeometry(window)
                hideOffscreen(window)
            }
        }
    }

    private func cleanActiveWorkspace() {
        var windows: [TrackedWindow] = []
        for window in workspaces[active] {
            guard window.isTileable(), !windows.contains(window) else { continue }
            windows.append(window)
        }
        workspaces[active] = windows
        pruneFloating()
        clampFocusedIndex()
    }

    private func deduplicateActiveWorkspace() {
        let unique = WorkspaceWindowDeduplication.unique(workspaces[active])
        guard unique.count != workspaces[active].count else { return }
        workspaces[active] = unique
        clampFocusedIndex()
    }

    private func clampFocusedIndex() {
        focusedIndices[active] = min(focusedIndices[active], max(workspaces[active].count - 1, 0))
    }

    private func scheduleWindowSettle(
        window: TrackedWindow,
        target: CGRect,
        step: Int,
        generation: UInt64,
        previousAttempt: WindowFrameSettleAttempt?
    ) {
        guard step < Self.windowSettleMaxSteps else { return }
        if step == 0,
            windowSettleState(
                window,
                target: target,
                generation: generation,
                previousAttempt: nil
            ) == nil
        {
            return
        }

        let delay = Self.windowSettleStepDelay
        extendGeometrySuppression(by: delay + Self.geometrySuppressionDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            guard
                let state = windowSettleState(
                    window,
                    target: target,
                    generation: generation,
                    previousAttempt: previousAttempt
                )
            else {
                return
            }
            let applied: Bool
            switch state.operation {
            case .position:
                applied = window.setPosition(target.origin, force: true)
            case .size:
                applied = window.setSize(target.size, force: true)
            }
            guard applied else { return }
            if layouts[active] == .monocle {
                selectedWindow()?.raise()
            }
            scheduleWindowSettle(
                window: window,
                target: target,
                step: step + 1,
                generation: generation,
                previousAttempt: WindowFrameSettleAttempt(
                    operation: state.operation,
                    frame: state.frame
                )
            )
        }
    }

    private func windowSettleState(
        _ window: TrackedWindow,
        target: CGRect,
        generation: UInt64,
        previousAttempt: WindowFrameSettleAttempt?
    ) -> (operation: FrameWriteOperation, frame: CGRect)? {
        guard geometryOperationGeneration == generation else { return nil }
        guard !WorkspaceManager.shared.isTilingPaused else { return nil }
        guard WorkspaceManager.shared.monitors.contains(where: { $0 === self }) else { return nil }
        guard workspaces.indices.contains(active) else { return nil }
        let tiled = workspaces[active].filter { !isFloating($0) }
        guard let index = tiled.firstIndex(of: window) else { return nil }
        let plan = currentArrangePlan(tiled: tiled)
        guard let slot = plan.visibleTiledIndices.firstIndex(of: index),
            plan.tiledFrames.indices.contains(slot)
        else { return nil }
        guard framesMatch(plan.tiledFrames[slot], target, tolerance: Self.frameTolerance) else { return nil }
        guard let frame = window.getFrame() else { return nil }
        guard
            let operation = WindowFrameSettlePlan.operation(
                current: frame,
                target: target,
                tolerance: Self.frameTolerance,
                previousAttempt: previousAttempt
            )
        else { return nil }
        return (operation, frame)
    }

    private func invalidateActiveWorkspaceAppliedGeometry() {
        for window in workspaces[active] {
            WindowManager.invalidateAppliedGeometry(window)
        }
    }

    private func activeWorkspaceMatchesLayout(tolerance: CGFloat) -> Bool {
        let tiled = nextTiled()
        let plan = currentArrangePlan(tiled: tiled)
        guard plan.tiledFrames.count == plan.visibleTiledIndices.count else { return false }
        let visible = Set(plan.visibleTiledIndices)
        for index in tiled.indices {
            guard tiled[index].isTileable(), let frame = tiled[index].getFrame() else { return false }
            if let slot = plan.visibleTiledIndices.firstIndex(of: index) {
                guard framesMatch(frame, plan.tiledFrames[slot], tolerance: tolerance) else { return false }
            } else if visible.contains(index) {
                return false
            }
        }
        return true
    }

    private func nextTiled() -> [TrackedWindow] {
        workspaces[active].filter { !isFloating($0) }
    }

    private func selectedWindow() -> TrackedWindow? {
        if workspaces[active].indices.contains(focusedIndices[active]) {
            return workspaces[active][focusedIndices[active]]
        }
        return WindowManager.focusedWindow()
    }

    private func pruneFloating() {
        let keys = Set(workspaces.joined().map(\.group))
        floating = floating.intersection(keys)
        floatingFrames = floatingFrames.filter { keys.contains($0.key) }
    }

    private func hideOffscreen(_ window: TrackedWindow) {
        rememberFloatingFrame(window)
        window.hideOffscreen(offscreenContext)
    }

    private func placedWindowFrames(windowCount: Int) -> [CGRect] {
        Tiler.calculateFrames(
            count: windowCount,
            screen: tileFrame,
            layout: layouts[active],
            masterRatio: Config.shared.masterRatio,
            gap: Config.shared.windowGap
        )
    }

    private func framesMatch(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private func suppressGeometryNotifications() {
        geometryOperationGeneration &+= 1
        ignoreGeometryUntil = ProcessInfo.processInfo.systemUptime + Self.geometrySuppressionDelay
    }

    private func extendGeometrySuppression(by delay: TimeInterval) {
        ignoreGeometryUntil = max(
            ignoreGeometryUntil,
            ProcessInfo.processInfo.systemUptime + delay
        )
    }

    package func resizeWorkspaces(to count: Int) {
        var state = MonitorWorkspaceState(
            workspaces: workspaces,
            layouts: layouts,
            focusedIndices: focusedIndices,
            active: active,
            previousActive: previousActive
        )
        state.resize(to: count)
        workspaces = state.workspaces
        layouts = state.layouts
        focusedIndices = state.focusedIndices
        active = state.active
        previousActive = state.previousActive
        persistLayouts()
    }

    func saveFocusedIndex() {
        guard let focused = WindowManager.focusedWindow(),
            rememberFocusedWindow(focused)
        else { return }
    }

    @discardableResult
    func rememberFocusedWindow(_ focused: TrackedWindow) -> Bool {
        guard let i = workspaces[active].firstIndex(of: focused) else { return false }
        workspaces[active][i] = focused.keepingMembers(from: workspaces[active][i])
        focusedIndices[active] = i
        return true
    }

    func copyState(from source: Monitor) {
        workspaces = source.workspaces
        layouts = source.layouts
        focusedIndices = source.focusedIndices
        active = source.active
        previousActive = source.previousActive
        floating = source.floating
        floatingFrames = source.floatingFrames
        persistLayouts()
    }

    func swapState(with other: Monitor) {
        let workspaces = workspaces
        let layouts = layouts
        let focusedIndices = focusedIndices
        let active = active
        let previousActive = previousActive
        let floating = floating
        let floatingFrames = floatingFrames

        copyState(from: other)

        other.workspaces = workspaces
        other.layouts = layouts
        other.focusedIndices = focusedIndices
        other.active = active
        other.previousActive = previousActive
        other.floating = floating
        other.floatingFrames = floatingFrames
        other.persistLayouts()
    }

    func migratePrimaryState(from source: Monitor) {
        let survivingFloating = floating
        let survivingFrames = floatingFrames
        var state = MonitorWorkspaceState(
            workspaces: workspaces,
            layouts: layouts,
            focusedIndices: focusedIndices,
            active: active,
            previousActive: previousActive
        )
        let sourceState = MonitorWorkspaceState(
            workspaces: source.workspaces,
            layouts: source.layouts,
            focusedIndices: source.focusedIndices,
            active: source.active,
            previousActive: source.previousActive
        )
        state.migratePrimaryState(from: sourceState)
        workspaces = state.workspaces
        layouts = state.layouts
        focusedIndices = state.focusedIndices
        active = state.active
        previousActive = state.previousActive
        floating = source.floating
        floatingFrames = source.floatingFrames
        let groups = Set(workspaces.flatMap { $0.map(\.group) })
        for key in survivingFloating where groups.contains(key) {
            floating.insert(key)
            if let frame = survivingFrames[key] {
                floatingFrames[key] = frame
            }
        }
        floating = floating.intersection(groups)
        floatingFrames = floatingFrames.filter { groups.contains($0.key) }
        persistLayouts()
    }

    func resetState() {
        retileDebounce.cancel()
        ignoreGeometryUntil = 0
        geometryOperationGeneration &+= 1
        let count = Config.shared.workspaceCount
        workspaces = Array(repeating: [], count: count)
        layouts = WorkspaceLayoutStore.load(displayID: displayID, count: count)
        focusedIndices = Array(repeating: 0, count: count)
        floating = []
        floatingFrames = [:]
        active = 0
        previousActive = 0
    }

    private func persistLayouts() {
        WorkspaceLayoutStore.save(displayID: displayID, layouts: layouts)
    }

    func restoreFocusedWindow(afterWorkspaceSwitch: Bool = false) {
        let windows = workspaces[active]
        guard let idx = WorkspaceFocusRestoration.index(savedIndex: focusedIndices[active], windowCount: windows.count)
        else {
            return
        }
        let target = windows[idx]
        if afterWorkspaceSwitch {
            WorkspaceManager.shared.suppressExternalFocusFollow()
            if activeWorkspaceHasMultipleProcesses() {
                target.focus()
            } else {
                target.focusAfterWorkspaceSwitch()
            }
        } else {
            target.focus()
        }
    }

    private func activeWorkspaceHasMultipleProcesses() -> Bool {
        let windows = workspaces[active]
        guard let first = windows.first?.pid else { return false }
        return windows.contains { $0.pid != first }
    }

    func focusAfterWindowRemoval(_ target: TrackedWindow) {
        guard let index = workspaces[active].firstIndex(of: target) else { return }
        focusedIndices[active] = index
        moveFocusGeneration &+= 1
        let scheduledGeneration = moveFocusGeneration
        WorkspaceManager.shared.suppressExternalFocusFollow()
        target.focus()
        DispatchQueue.main.async { [self] in
            guard moveFocusGeneration == scheduledGeneration else { return }
            guard workspaces[active].contains(target) else { return }
            WorkspaceManager.shared.suppressExternalFocusFollow()
            target.focus()
        }
    }

    private func scheduleFocusedWindowRestore(activeWorkspace expectedActive: Int) {
        focusRestoreGeneration &+= 1
        let scheduledGeneration = focusRestoreGeneration
        DispatchQueue.main.async { [self] in
            guard active == expectedActive else { return }
            guard focusRestoreGeneration == scheduledGeneration else { return }
            PerformanceTelemetry.measure(.focusRestore) {
                restoreFocusedWindow(afterWorkspaceSwitch: true)
            }
        }
    }

    func restoreAllWindows() {
        let screen = tileFrame
        let center = CGPoint(
            x: screen.origin.x + screen.width / 4,
            y: screen.origin.y + screen.height / 4
        )
        let size = CGSize(width: screen.width / 2, height: screen.height / 2)

        for ws in workspaces {
            for win in ws {
                win.setFrame(CGRect(origin: center, size: size))
            }
        }
    }
}
