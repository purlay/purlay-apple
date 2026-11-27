import SwiftUI

/// The Purlay mark: the logo's shapes and gradients (`Logo`, written from `Design/purlay.svg` by scripts/icon), drawn at any size.
///
/// It fills the square it is given, whatever the frame, so a caller sets the size and nothing else.
public struct PurlayMark: View {
    /// How large the launch screen and the Welcome screen draw it.
    public static let launchSize: CGFloat = 120

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Logo.canvas
            context.translateBy(x: (size.width - Logo.canvas * scale) / 2, y: (size.height - Logo.canvas * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            for shape in Logo.shapes {
                context.fill(
                    shape.path,
                    with: .linearGradient(Gradient(stops: shape.stops), startPoint: shape.start, endPoint: shape.end))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
