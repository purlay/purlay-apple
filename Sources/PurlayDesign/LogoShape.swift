import SwiftUI

/// One of the logo's shapes as the SVG states it: the outline, step by step, and the gradient that fills it, in the SVG's own
/// coordinates. `Logo` holds the logo's shapes; this only draws one.
struct LogoShape {
    /// A step of an SVG path, in absolute coordinates: `M`, `L` (and `H` and `V`, written as lines), `C` and `Z`.
    enum Step {
        case move(CGFloat, CGFloat)
        case line(CGFloat, CGFloat)
        case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        case close
    }

    let stops: [Gradient.Stop]
    let start: CGPoint
    let end: CGPoint
    let steps: [Step]

    var path: Path {
        Path { path in
            for step in steps {
                switch step {
                case .move(let x, let y): path.move(to: CGPoint(x: x, y: y))
                case .line(let x, let y): path.addLine(to: CGPoint(x: x, y: y))
                case .curve(let x1, let y1, let x2, let y2, let x, let y):
                    path.addCurve(
                        to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
                case .close: path.closeSubpath()
                }
            }
        }
    }
}
