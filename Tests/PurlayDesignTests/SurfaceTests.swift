import SwiftUI
import Testing

@testable import PurlayDesign

@MainActor
@Suite("surfaces")
struct SurfaceTests {
    @Test("a surface lies behind what it holds and takes no room of its own, for every role and shape")
    func takesNoRoom() throws {
        for role in [SurfaceRole.floatingControl, .panel] {
            let shapes: [AnyShape] = [AnyShape(Capsule()), AnyShape(RoundedRectangle(cornerRadius: 12))]
            for shape in shapes {
                let content = Color.clear.frame(width: 80, height: 30).purlaySurface(role, in: shape)
                let image = try #require(ImageRenderer(content: content).cgImage)
                #expect(image.width == 80 && image.height == 30, "\(role)")
            }
        }
    }
}
