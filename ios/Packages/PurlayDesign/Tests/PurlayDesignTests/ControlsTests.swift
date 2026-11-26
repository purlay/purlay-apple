import SwiftUI
import Testing

@testable import PurlayDesign

@MainActor
@Suite("controls")
struct ControlsTests {
    @Test("each seam builds")
    func buildsEverywhere() {
        _ = Button(action: {}) { Text("x") }.purlayButton(.primary)
        _ = Text("x").purlayBottomBar { Text("y") }
        _ = PurlayNoticeStack { Text("x").purlayNoticeTransition() }
    }
}
