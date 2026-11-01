import CoreGraphics
import Testing

@testable import ParketCore

@Suite("Window session store")
struct WindowSessionStoreTests {
    @Test func takePrefersSameDisplayThenFallsBack() {
        var records = [
            SessionWindowRecord(
                bundleID: "com.apple.Safari",
                title: "Home",
                displayID: 2,
                workspace: 3,
                floating: false
            ),
            SessionWindowRecord(
                bundleID: "com.apple.Safari",
                title: "Home",
                displayID: 1,
                workspace: 1,
                floating: true
            ),
        ]

        let first = WindowSessionMatching.take(
            from: &records,
            bundleID: "com.apple.Safari",
            title: "Home",
            displayID: 1,
            workspaceCount: 10
        )
        #expect(first?.displayID == 1)
        #expect(first?.workspace == 1)
        #expect(first?.floating == true)

        let second = WindowSessionMatching.take(
            from: &records,
            bundleID: "com.apple.Safari",
            title: "Home",
            displayID: 9,
            workspaceCount: 10
        )
        #expect(second?.displayID == 2)
        #expect(second?.workspace == 3)
        #expect(records.isEmpty)
    }

    @Test func takeSkipsInvalidWorkspaceIndexes() {
        var records = [
            SessionWindowRecord(
                bundleID: "app",
                title: "A",
                displayID: 1,
                workspace: 20,
                floating: false
            )
        ]
        let match = WindowSessionMatching.take(
            from: &records,
            bundleID: "app",
            title: "A",
            displayID: 1,
            workspaceCount: 10
        )
        #expect(match == nil)
        #expect(records.count == 1)
    }
}
