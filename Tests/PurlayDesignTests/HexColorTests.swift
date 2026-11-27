import PurlayTokens
import SwiftUI
import Testing

@testable import PurlayDesign

/// One reading of `0xRRGGBB` for the whole app: the tokens', which the mark and the Welcome field draw through too.
@Suite("a colour written in hex")
struct HexColorTests {
    @Test("is the token reading of the same value, channel for channel")
    func sameAsTheTokens() {
        for hex: UInt32 in [0x000000, 0xFFFFFF, 0x2563EB, 0x0EA5EE, 0x78BDF2] {
            let token = RGBA(hex: hex)
            let expected = Color(.sRGB, red: token.red, green: token.green, blue: token.blue).resolve(
                in: EnvironmentValues())
            #expect(Color(hex: hex).resolve(in: EnvironmentValues()) == expected, "\(hex)")
        }
    }
}
