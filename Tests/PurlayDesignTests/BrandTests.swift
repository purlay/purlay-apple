import PurlayTokens
import SwiftUI
import Testing

@testable import PurlayDesign

#if canImport(AppKit)
import AppKit
#endif

@Suite("brand")
struct BrandTests {
    @Test("white on the accent is readable at body size")
    func accentContrast() {
        for appearance in Appearance.allCases {
            let ratio = RGBA.contrast(Colors.onAccent.value(in: appearance), Colors.accent.value(in: appearance))
            #expect(ratio >= 4.5)
        }
    }

    // On the main actor: a colour that follows the appearance is resolved through AppKit or UIKit, which wait for it.
    @Test("each brand colour is its token's value, in light and in dark")
    @MainActor
    func colorsAreTheTokens() {
        let pairs: [(Color, TokenColor)] = [
            (Brand.accent, Colors.accent), (Brand.onAccent, Colors.onAccent), (Brand.ink, Colors.ink),
            (Brand.inkMuted, Colors.inkMuted),
        ]
        for (colour, token) in pairs {
            for (scheme, appearance) in [(ColorScheme.light, Appearance.light), (.dark, .dark)] {
                var environment = EnvironmentValues()
                environment.colorScheme = scheme
                let drawn = colour.resolve(in: environment)
                let value = token.value(in: appearance)
                let channels = [
                    (drawn.red, value.red), (drawn.green, value.green), (drawn.blue, value.blue),
                ]
                for (drawnChannel, tokenChannel) in channels {
                    // Color.Resolved is linear-free sRGB in 0…1; one step of 255 is the most rounding may move it.
                    #expect(abs(Double(drawnChannel) - tokenChannel) <= 1.0 / 255, "\(token.name), \(scheme)")
                }
            }
        }
    }

    #if canImport(AppKit)
    /// The most a channel may differ before it counts as different, and the share of channels that may: the two renderers
    /// smooth the edges differently, and nothing else. Measured: 0.095 % of the channels differed by more than 24 on the iOS
    /// simulator (the entry slice's QA), 0.12 % here on macOS; a mark drawn wrong differs in far more.
    private static let channelTolerance = 24
    private static let differingShareAllowed = 0.002

    @Test("drawn at 120 points, the mark is the launch screen's mark, pixel for pixel")
    @MainActor
    func markIsTheLaunchMark() throws {
        let scale = 2
        let side = Int(PurlayMark.launchSize) * scale
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let launch = try #require(
            NSImage(
                contentsOf: root.appending(
                    path: "Apps/iOS/App/Resources/Assets.xcassets/LaunchMark.imageset/purlay-mark.svg")))
        let renderer = ImageRenderer(
            content: PurlayMark().frame(width: PurlayMark.launchSize, height: PurlayMark.launchSize))
        renderer.scale = CGFloat(scale)
        let mark = try #require(renderer.cgImage)
        let frame = CGRect(x: 0, y: 0, width: side, height: side)

        let drawnMark = try #require(Self.pixels(side: side) { $0.draw(mark, in: frame) })
        let drawnLaunch = try #require(
            Self.pixels(side: side) { context in
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                launch.draw(in: frame)
                NSGraphicsContext.restoreGraphicsState()
            })

        #expect(drawnMark.contains { $0 > 0 }, "the mark drew nothing")
        let differing = zip(drawnMark, drawnLaunch).filter { abs(Int($0) - Int($1)) > Self.channelTolerance }.count
        let share = Double(differing) / Double(drawnMark.count)
        #expect(share <= Self.differingShareAllowed, "\(share * 100) % of the channels differ")
    }

    /// The RGBA bytes of what `draw` draws on a clear square of this many pixels, in sRGB.
    private static func pixels(side: Int, draw: (CGContext) -> Void) -> [UInt8]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let data = context.data
        else { return nil }
        draw(context)
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: side * side * 4))
    }
    #endif
}
