import SwiftUI

/// The Purlay mark, drawn from `Design/purlay.svg` and kept in step with it by hand: change the SVG and this together.
///
/// It fills the square it is given, whatever the frame, so a caller sets the size and nothing else.
public struct PurlayMark: View {
    /// How large the launch screen and the Welcome screen draw it.
    public static let launchSize: CGFloat = 120

    private static let canvas: CGFloat = 1024

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.canvas
            context.translateBy(x: (size.width - Self.canvas * scale) / 2, y: (size.height - Self.canvas * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            for part in Part.allCases {
                context.fill(part.path, with: part.shading)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

extension PurlayMark {
    /// The three shapes, back to front, each with the gradient the SVG gives it (in the SVG's own coordinates).
    fileprivate enum Part: CaseIterable {
        case stem, fold, ribbon

        var shading: GraphicsContext.Shading {
            switch self {
            case .stem:
                gradient(
                    [(0, 0x0759EB), (1, 0x0EA5EE)], from: CGPoint(x: 330, y: 550), to: CGPoint(x: 330, y: 876))
            case .fold:
                gradient(
                    [(0, 0x15B8EE), (0.52, 0x0869DF), (1, 0x09358F)], from: CGPoint(x: 250, y: 500),
                    to: CGPoint(x: 610, y: 500))
            case .ribbon:
                gradient(
                    [(0, 0x249FEC), (0.52, 0x78BDF2), (1, 0xA8D4F7)], from: CGPoint(x: 270, y: 730),
                    to: CGPoint(x: 690, y: 210))
            }
        }

        var path: Path {
            switch self {
            case .stem: Self.stemPath
            case .fold: Self.foldPath
            case .ribbon: Self.ribbonPath
            }
        }

        private func gradient(
            _ stops: [(location: CGFloat, hex: UInt32)], from start: CGPoint, to end: CGPoint
        ) -> GraphicsContext.Shading {
            .linearGradient(
                Gradient(stops: stops.map { .init(color: Color(hex: $0.hex), location: $0.location) }),
                startPoint: start, endPoint: end)
        }

        private static let stemPath = Path { path in
            path.move(to: CGPoint(x: 248, y: 544))
            path.addCurve(
                to: CGPoint(x: 351, y: 441), control1: CGPoint(x: 248, y: 487), control2: CGPoint(x: 294, y: 441))
            path.addLine(to: CGPoint(x: 420, y: 441))
            path.addLine(to: CGPoint(x: 420, y: 745))
            path.addCurve(
                to: CGPoint(x: 333, y: 832), control1: CGPoint(x: 420, y: 793), control2: CGPoint(x: 381, y: 832))
            path.addCurve(
                to: CGPoint(x: 248, y: 746), control1: CGPoint(x: 286, y: 832), control2: CGPoint(x: 248, y: 794))
            path.closeSubpath()
        }

        private static let foldPath = Path { path in
            path.move(to: CGPoint(x: 248, y: 544))
            path.addCurve(
                to: CGPoint(x: 351, y: 441), control1: CGPoint(x: 248, y: 487), control2: CGPoint(x: 294, y: 441))
            path.addLine(to: CGPoint(x: 585, y: 441))
            path.addCurve(
                to: CGPoint(x: 612, y: 468), control1: CGPoint(x: 600, y: 441), control2: CGPoint(x: 612, y: 453))
            path.addLine(to: CGPoint(x: 612, y: 522))
            path.addLine(to: CGPoint(x: 510, y: 522))
            path.addCurve(
                to: CGPoint(x: 248, y: 667), control1: CGPoint(x: 398, y: 522), control2: CGPoint(x: 301, y: 583))
            path.closeSubpath()
        }

        private static let ribbonPath = Path { path in
            path.move(to: CGPoint(x: 324, y: 192))
            path.addLine(to: CGPoint(x: 574, y: 192))
            path.addCurve(
                to: CGPoint(x: 776, y: 395), control1: CGPoint(x: 686, y: 192), control2: CGPoint(x: 776, y: 283))
            path.addCurve(
                to: CGPoint(x: 574, y: 598), control1: CGPoint(x: 776, y: 507), control2: CGPoint(x: 686, y: 598))
            path.addLine(to: CGPoint(x: 438, y: 598))
            path.addCurve(
                to: CGPoint(x: 248, y: 723), control1: CGPoint(x: 361, y: 598), control2: CGPoint(x: 290, y: 648))
            path.addLine(to: CGPoint(x: 248, y: 613))
            path.addCurve(
                to: CGPoint(x: 510, y: 464), control1: CGPoint(x: 301, y: 536), control2: CGPoint(x: 399, y: 464))
            path.addLine(to: CGPoint(x: 574, y: 464))
            path.addCurve(
                to: CGPoint(x: 644, y: 395), control1: CGPoint(x: 612, y: 464), control2: CGPoint(x: 644, y: 433))
            path.addCurve(
                to: CGPoint(x: 574, y: 326), control1: CGPoint(x: 644, y: 357), control2: CGPoint(x: 612, y: 326))
            path.addLine(to: CGPoint(x: 324, y: 326))
            path.addCurve(
                to: CGPoint(x: 248, y: 259), control1: CGPoint(x: 282, y: 326), control2: CGPoint(x: 248, y: 296))
            path.addCurve(
                to: CGPoint(x: 324, y: 192), control1: CGPoint(x: 248, y: 222), control2: CGPoint(x: 282, y: 192))
            path.closeSubpath()
        }
    }
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255)
    }
}
