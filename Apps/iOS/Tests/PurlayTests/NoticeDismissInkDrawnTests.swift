import PurlayDesign
import SwiftUI
import Testing

@testable import Purlay

/// `NoticeDismissContrastTests` measures `NoticeBanner.dismissInk`, a constant: it stays green when the xmark stops using it
/// (seen: the `.foregroundStyle(Self.dismissInk)` line removed, the test passed). This draws the banner and looks at the glyph.
@MainActor
@Suite("the notice's dismiss glyph is drawn in the accent's text ink")
struct NoticeDismissInkDrawnTests {
    @Test("the drawn xmark is accent-text, not the accent fill, in light and dark", arguments: [ColorScheme.light, .dark])
    func drawnInk(scheme: ColorScheme) throws {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let text = Brand.accentText.resolve(in: environment)
        let fill = Brand.accent.resolve(in: environment)
        let renderer = ImageRenderer(
            content: NoticeBanner(words: "Saved.", dismiss: {}).frame(width: 390).environment(\.colorScheme, scheme))
        renderer.scale = 3
        let image = try #require(renderer.cgImage)
        let pixels = try #require(Self.pixels(image))
        func near(_ colour: Color.Resolved) -> Int {
            let target = (Double(colour.red), Double(colour.green), Double(colour.blue))
            return pixels.filter { abs($0.0 - target.0) + abs($0.1 - target.1) + abs($0.2 - target.2) < 0.06 }.count
        }
        let textInk = near(text)
        let fillInk = near(fill)
        #expect(textInk > 20, "\(scheme): \(textInk) pixels of accent-text")
        #expect(fillInk < textInk / 10, "\(scheme): \(fillInk) pixels of the accent fill, \(textInk) of accent-text")
    }

    /// The image's pixels as linear-free sRGB components in 0…1, alpha-weighted pixels skipped.
    private static func pixels(_ image: CGImage) -> [(Double, Double, Double)]? {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: bytes.count, by: 4).compactMap { index in
            guard bytes[index + 3] == 255 else { return nil }
            return (Double(bytes[index]) / 255, Double(bytes[index + 1]) / 255, Double(bytes[index + 2]) / 255)
        }
    }
}
