import PurlayDesign
import SwiftUI

/// The quiet field of brand blues behind Welcome. It drifts slowly, and SwiftUI interpolates the drift: no work of ours runs
/// per frame. It holds still under Reduce Motion and in Low Power Mode.
struct EntryBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var drifted = false

    /// One way of the drift; it then returns. Slower than this would be invisible, faster would draw the eye.
    private static let drift = Animation.easeInOut(duration: 20).repeatForever(autoreverses: true)

    var body: some View {
        MeshGradient(width: 3, height: 3, points: moves && drifted ? Self.drifted : Self.resting, colors: Self.colors)
            // A new identity when motion is allowed or refused: a repeating animation cannot be stopped otherwise.
            .id(moves)
            .animation(moves ? Self.drift : nil, value: drifted)
            .opacity(colorScheme == .dark ? 0.28 : 0.18)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .onChange(of: moves, initial: true) { _, moves in drifted = moves }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                    lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
            }
    }

    private var moves: Bool { !reduceMotion && !lowPower }

    /// The logo's own blues (`Logo`, from Design/purlay.svg), light to deep, so the field reads as the mark's colour.
    private static let colors: [Color] = [
        Logo.ribbonEnd, Logo.ribbonMiddle, Logo.stemEnd,
        Logo.ribbonMiddle, Logo.stemEnd, Logo.stemStart,
        Logo.stemEnd, Logo.stemStart, Logo.ribbonMiddle,
    ]

    /// The corners and the centre stay; the four points in the middle of the edges slide along their edges.
    private static let resting: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.5, 0.5], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
    ]
    private static let drifted: [SIMD2<Float>] = [
        [0, 0], [0.75, 0], [1, 0],
        [0, 0.3], [0.5, 0.5], [1, 0.7],
        [0, 1], [0.25, 1], [1, 1],
    ]
}

#Preview("Light") {
    EntryBackdrop()
}

#Preview("Dark") {
    EntryBackdrop().preferredColorScheme(.dark)
}
