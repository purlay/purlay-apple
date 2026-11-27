import SwiftUI
import Testing

@testable import Purlay

@MainActor
@Suite("a notice's dismiss glyph is seen on its glass")
struct NoticeDismissContrastTests {
    // Measured on the AX5 simulator shots (shots-ax5/dark-*-portrait-notice-*.png): the glass panel beside the xmark is
    // #27586F in dark and #EAFCFF in light. The glyph took the app's tint, the accent token #2563EB (a fill colour; the token
    // says text and icons take accent-text): 1.9:1 in dark, under the 3:1 a control's glyph needs (WCAG 1.4.11).
    private static let darkPanel = (red: 0x27, green: 0x58, blue: 0x6F)
    private static let lightPanel = (red: 0xEA, green: 0xFC, blue: 0xFF)

    @Test(
        "the dismiss glyph has 3:1 against the glass panel, in light and dark", arguments: [ColorScheme.light, .dark])
    func glyphContrast(scheme: ColorScheme) {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let ink = NoticeBanner.dismissInk.resolve(in: environment)
        let panel = scheme == .dark ? Self.darkPanel : Self.lightPanel
        let ratio = Self.contrast(
            (Double(ink.red), Double(ink.green), Double(ink.blue)),
            (Double(panel.red) / 255, Double(panel.green) / 255, Double(panel.blue) / 255))
        #expect(ratio >= 3, "\(scheme): \(ratio):1")
    }

    private static func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        func linear(_ value: Double) -> Double { value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        func luminance(_ c: (Double, Double, Double)) -> Double {
            0.2126 * linear(c.0) + 0.7152 * linear(c.1) + 0.0722 * linear(c.2)
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
