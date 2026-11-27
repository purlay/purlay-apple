import SwiftUI
import Testing

@testable import PurlayDesign

@MainActor
@Suite("controls")
struct ControlsTests {
    @Test("notices stack one above the other, 8 points apart, on every OS")
    func noticesStack() throws {
        let stack = PurlayNoticeStack {
            Color.red.frame(width: 40, height: 20)
            Color.red.frame(width: 40, height: 30)
        }
        let image = try #require(ImageRenderer(content: stack).cgImage)
        #expect(image.width == 40)
        #expect(image.height == 20 + 8 + 30)
    }
}
