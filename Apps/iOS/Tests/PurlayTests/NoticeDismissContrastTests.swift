import PurlayDesign
import SwiftUI
import Testing

@testable import Purlay

@MainActor
@Suite("a notice's dismiss glyph is seen on its glass")
struct NoticeDismissContrastTests {
    // Measured on the AX5 simulator shots (shots-ax5/dark-*-portrait-notice-*.png): the glass panel beside the xmark is
    // #27586F in dark and #EAFCFF in light. The glyph took the app's tint, the accent token #2563EB (a fill colour; the token
    // says text and icons take accent-text): 1.9:1 in dark, under the 3:1 a control's glyph needs (WCAG 1.4.11).
    // ImageRenderer does not draw the glass, so the glyph drawn by the banner is measured against these.
    private static let darkPanel = (red: 0x27, green: 0x58, blue: 0x6F)
    private static let lightPanel = (red: 0xEA, green: 0xFC, blue: 0xFF)
    /// The banner's width, and the trailing part of it that holds the dismiss button (8 of padding, 44 of target).
    private static let width: CGFloat = 390
    private static let dismissColumn: CGFloat = 56
    private static let scale: CGFloat = 3

    // A test of `NoticeBanner.dismissInk` alone stayed green with the xmark's `.foregroundStyle` removed: the glyph is drawn
    // here and its own ink is what is measured.
    @Test(
        "the drawn dismiss glyph has 3:1 against the glass panel, in the accent's text ink, in light and dark",
        arguments: [ColorScheme.light, .dark])
    func drawnGlyphContrast(scheme: ColorScheme) throws {
        let renderer = ImageRenderer(
            content: NoticeBanner(words: "Saved.", dismiss: {}).frame(width: Self.width)
                .environment(\.colorScheme, scheme))
        renderer.scale = Self.scale
        let image = try #require(renderer.cgImage)
        let glyph = try #require(Self.ink(image), "\(scheme): no glyph drawn in the dismiss column")

        let panel = scheme == .dark ? Self.darkPanel : Self.lightPanel
        let ratio = Self.contrast(
            glyph, (Double(panel.red) / 255, Double(panel.green) / 255, Double(panel.blue) / 255))
        #expect(ratio >= 3, "\(scheme): the drawn glyph \(glyph) is \(ratio):1 on the glass")

        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let text = Brand.accentText.resolve(in: environment)
        let distance = Self.distance(glyph, (Double(text.red), Double(text.green), Double(text.blue)))
        #expect(distance < 0.06, "\(scheme): the drawn glyph \(glyph) is not accent-text \(text)")
    }

    /// The glyph's ink in the dismiss column, as sRGB components in 0…1. ImageRenderer draws the glass as a flat fill, the most
    /// common colour there; the glyph's core is the most common colour clearly apart from it (its anti-aliased edge is thinner
    /// than its stroke).
    private static func ink(_ image: CGImage) -> (Double, Double, Double)? {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let firstColumn = width - Int(dismissColumn * scale)
        var counts: [UInt32: Int] = [:]
        for row in 0..<height {
            for column in max(firstColumn, 0)..<width {
                let pixel = (row * width + column) * 4
                guard bytes[pixel + 3] == 255 else { continue }
                let key = UInt32(bytes[pixel]) << 16 | UInt32(bytes[pixel + 1]) << 8 | UInt32(bytes[pixel + 2])
                counts[key, default: 0] += 1
            }
        }
        func components(_ key: UInt32) -> (Double, Double, Double) {
            (Double(key >> 16 & 0xFF) / 255, Double(key >> 8 & 0xFF) / 255, Double(key & 0xFF) / 255)
        }
        guard let (panel, _) = counts.max(by: { $0.value < $1.value }) else { return nil }
        let marks = counts.filter { distance(components($0.key), components(panel)) > 0.3 }
        guard let (glyph, count) = marks.max(by: { $0.value < $1.value }), count > 20 else { return nil }
        return components(glyph)
    }

    private static func distance(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2)
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
