import SwiftUI
import Testing
import UIKit

@testable import Purlay

@MainActor
@Suite("Welcome's words on the backdrop")
struct WelcomeContrastTests {
    // The tagline and the footer over EntryBackdrop's tinted field, in the style Welcome draws them in. As `.secondary` the
    // simulator measured 3.3:1 to 3.4:1 in light mode, below the 4.5:1 that text of this size needs.
    @Test(
        "the tagline and the footer are readable, in light and dark",
        arguments: [ColorScheme.light, .dark])
    func readable(scheme: ColorScheme) throws {
        for (words, font) in Self.lines {
            let ratio = try Self.contrast(words, font, scheme, .standard)
            #expect(ratio >= 4.5, "\(scheme), \(String(localized: words)): \(ratio):1")
        }
    }

    // Increase Contrast asks for more than the minimum: the quiet lines take a stronger ink than they do by default.
    @Test(
        "with Increase Contrast the tagline and the footer are stronger still, in light and dark",
        arguments: [ColorScheme.light, .dark])
    func increased(scheme: ColorScheme) throws {
        for (words, font) in Self.lines {
            let standard = try Self.contrast(words, font, scheme, .standard)
            let increased = try Self.contrast(words, font, scheme, .increased)
            #expect(increased >= 7, "\(scheme), \(String(localized: words)): \(increased):1")
            #expect(
                increased > standard, "\(scheme), \(String(localized: words)): \(increased):1, not above \(standard):1")
        }
    }

    private static let lines: [(LocalizedStringResource, Font)] = [
        (Words.tagline, .title3), (Words.newAccount, .footnote),
    ]

    private static func contrast(
        _ words: LocalizedStringResource, _ font: Font, _ scheme: ColorScheme, _ contrast: ColorSchemeContrast
    ) throws -> Double {
        let picture = ZStack {
            EntryBackdrop()
            Text(words).font(font).foregroundStyle(WelcomeView.quietInk(contrast))
        }
        .frame(width: 390, height: 120)
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: picture)
        renderer.scale = 3
        let image = try #require(renderer.cgImage)
        return try #require(Self.textContrast(image))
    }

    /// The contrast between the background (the median pixel) and the text (the pixel farthest from it in luminance).
    private static func textContrast(_ image: CGImage) -> Double? {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        func linear(_ byte: UInt8) -> Double {
            let value = Double(byte) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)
        for pixel in stride(from: 0, to: bytes.count, by: 4) {
            luminances.append(
                0.2126 * linear(bytes[pixel]) + 0.7152 * linear(bytes[pixel + 1]) + 0.0722 * linear(bytes[pixel + 2]))
        }
        luminances.sort()
        guard let darkest = luminances.first, let lightest = luminances.last else { return nil }
        let background = luminances[luminances.count / 2]
        let text = abs(darkest - background) > abs(lightest - background) ? darkest : lightest
        return (max(text, background) + 0.05) / (min(text, background) + 0.05)
    }
}
