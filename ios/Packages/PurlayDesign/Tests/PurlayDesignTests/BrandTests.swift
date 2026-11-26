import PurlayTokens
import SwiftUI
import Testing

@testable import PurlayDesign

@Suite("brand")
struct BrandTests {
    @Test("white on the accent is readable at body size")
    func accentContrast() {
        for appearance in Appearance.allCases {
            let ratio = RGBA.contrast(Colors.onAccent.value(in: appearance), Colors.accent.value(in: appearance))
            #expect(ratio >= 4.5)
        }
    }

    @Test("the mark can be drawn")
    @MainActor
    func mark() {
        _ = PurlayMark().frame(width: PurlayMark.launchSize)
    }
}
