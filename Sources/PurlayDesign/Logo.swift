// Written by scripts/icon from Design/purlay.svg, and refused by scripts/enforcement when it is not what the logo says.
// Change the logo and run scripts/icon; never edit this file.
import SwiftUI

/// The logo as `Design/purlay.svg` draws it, in the SVG's own coordinates: its colours, by gradient, and its shapes.
public enum Logo {
    public static let stemStart = Color(hex: 0x0759EB)
    public static let stemEnd = Color(hex: 0x0EA5EE)
    public static let foldStart = Color(hex: 0x15B8EE)
    public static let foldMiddle = Color(hex: 0x0869DF)
    public static let foldEnd = Color(hex: 0x09358F)
    public static let ribbonStart = Color(hex: 0x249FEC)
    public static let ribbonMiddle = Color(hex: 0x78BDF2)
    public static let ribbonEnd = Color(hex: 0xA8D4F7)

    /// The side of the square the logo is drawn in.
    static let canvas: CGFloat = 1024

    /// The shapes, back to front, each filled with its gradient.
    static let shapes: [LogoShape] = [
        LogoShape(
            stops: [
                Gradient.Stop(color: stemStart, location: 0),
                Gradient.Stop(color: stemEnd, location: 1),
            ],
            start: CGPoint(x: 330, y: 550),
            end: CGPoint(x: 330, y: 876),
            steps: [
                .move(248, 544),
                .curve(248, 487, 294, 441, 351, 441),
                .line(420, 441),
                .line(420, 745),
                .curve(420, 793, 381, 832, 333, 832),
                .curve(286, 832, 248, 794, 248, 746),
                .close,
            ]
        ),
        LogoShape(
            stops: [
                Gradient.Stop(color: foldStart, location: 0),
                Gradient.Stop(color: foldMiddle, location: 0.52),
                Gradient.Stop(color: foldEnd, location: 1),
            ],
            start: CGPoint(x: 250, y: 500),
            end: CGPoint(x: 610, y: 500),
            steps: [
                .move(248, 544),
                .curve(248, 487, 294, 441, 351, 441),
                .line(585, 441),
                .curve(600, 441, 612, 453, 612, 468),
                .line(612, 522),
                .line(510, 522),
                .curve(398, 522, 301, 583, 248, 667),
                .close,
            ]
        ),
        LogoShape(
            stops: [
                Gradient.Stop(color: ribbonStart, location: 0),
                Gradient.Stop(color: ribbonMiddle, location: 0.52),
                Gradient.Stop(color: ribbonEnd, location: 1),
            ],
            start: CGPoint(x: 270, y: 730),
            end: CGPoint(x: 690, y: 210),
            steps: [
                .move(324, 192),
                .line(574, 192),
                .curve(686, 192, 776, 283, 776, 395),
                .curve(776, 507, 686, 598, 574, 598),
                .line(438, 598),
                .curve(361, 598, 290, 648, 248, 723),
                .line(248, 613),
                .curve(301, 536, 399, 464, 510, 464),
                .line(574, 464),
                .curve(612, 464, 644, 433, 644, 395),
                .curve(644, 357, 612, 326, 574, 326),
                .line(324, 326),
                .curve(282, 326, 248, 296, 248, 259),
                .curve(248, 222, 282, 192, 324, 192),
                .close,
            ]
        ),
    ]
}
