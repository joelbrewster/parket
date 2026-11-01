import CoreGraphics
import Foundation

package enum WorkspaceFocusCycle {
    package static func targetIndex(current: Int, offset: Int, count: Int) -> Int? {
        guard count > 1, current >= 0, current < count else { return nil }
        return (current + offset % count + count) % count
    }

    package static func resolveCurrentIndex(
        focusedIndex: Int?,
        savedIndex: Int,
        count: Int
    ) -> Int? {
        if let focusedIndex, focusedIndex >= 0, focusedIndex < count {
            return focusedIndex
        }
        guard count > 0, savedIndex >= 0, savedIndex < count else { return nil }
        return savedIndex
    }
}

package enum TileVisibility {
    package static let maxVisible = 3

    package static func visibleIndices(
        tiledCount: Int,
        focusedTiledIndex: Int?,
        maxVisible: Int = maxVisible
    ) -> [Int] {
        guard tiledCount > 0 else { return [] }
        guard tiledCount > maxVisible else { return Array(0..<tiledCount) }
        let focus = min(max(focusedTiledIndex ?? 0, 0), tiledCount - 1)
        if focus < maxVisible {
            return Array(0..<maxVisible)
        }
        var indices = [0]
        let stackSlots = maxVisible - 1
        let stackStart = focus - stackSlots + 1
        for index in stackStart...focus where index > 0 {
            indices.append(index)
        }
        return indices
    }
}

package struct ArrangePlan: Equatable {
    package var tiledFrames: [CGRect]
    package var visibleTiledIndices: [Int]
    package var raiseSelectedAboveFloaters: Bool
}

package enum ArrangePlanner {
    package static func plan(
        tileFrame: CGRect,
        layout: Layout,
        tiledCount: Int,
        focusedTiledIndex: Int?,
        selectedIsTiled: Bool,
        floatingCount: Int,
        masterRatio: CGFloat = Tiler.defaultMasterRatio,
        gap: CGFloat = 0,
        maxVisibleTiled: Int = TileVisibility.maxVisible
    ) -> ArrangePlan {
        let visibleIndices: [Int]
        switch layout {
        case .monocle:
            visibleIndices = Array(0..<tiledCount)
        case .tile:
            visibleIndices = TileVisibility.visibleIndices(
                tiledCount: tiledCount,
                focusedTiledIndex: focusedTiledIndex,
                maxVisible: maxVisibleTiled
            )
        }
        let frames = Tiler.calculateFrames(
            count: visibleIndices.count,
            screen: tileFrame,
            layout: layout,
            masterRatio: masterRatio,
            gap: gap
        )
        return ArrangePlan(
            tiledFrames: frames,
            visibleTiledIndices: visibleIndices,
            raiseSelectedAboveFloaters: layout == .monocle && selectedIsTiled && floatingCount > 0
        )
    }
}
