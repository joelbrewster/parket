import Foundation

package enum Layout {
    case tile
    case monocle

    static let initial = Layout.monocle
}

package enum Tiler {
    package static let defaultMasterRatio: CGFloat = 0.45

    package static func calculateFrames(
        count: Int,
        screen: CGRect,
        layout: Layout,
        masterRatio: CGFloat = defaultMasterRatio,
        gap: CGFloat = 0
    ) -> [CGRect] {
        guard count > 0 else { return [] }
        switch layout {
        case .tile:
            return tileFrames(count: count, screen: screen, masterRatio: masterRatio, gap: max(0, gap))
        case .monocle:
            return monocleFrames(count: count, screen: screen)
        }
    }

    private static func tileFrames(
        count: Int,
        screen: CGRect,
        masterRatio: CGFloat,
        gap: CGFloat
    ) -> [CGRect] {
        if count == 1 {
            return [screen]
        }

        let masterWidth = max(0, floor((screen.width - gap) * masterRatio))
        let stackWidth = max(0, screen.width - masterWidth - gap)
        var result: [CGRect] = []
        result.reserveCapacity(count)
        result.append(
            CGRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: masterWidth,
                height: screen.height
            ))

        let stackCount = count - 1
        let usableHeight = max(0, screen.height - gap * CGFloat(stackCount - 1))
        let stackHeight = floor(usableHeight / CGFloat(stackCount))
        var y = screen.origin.y
        for i in 0..<stackCount {
            let isLast = i == stackCount - 1
            let height = isLast ? max(0, screen.maxY - y) : stackHeight
            result.append(
                CGRect(
                    x: screen.origin.x + masterWidth + gap,
                    y: y,
                    width: stackWidth,
                    height: height
                ))
            y += height + gap
        }
        return result
    }

    private static func monocleFrames(count: Int, screen: CGRect) -> [CGRect] {
        Array(repeating: screen, count: count)
    }
}
