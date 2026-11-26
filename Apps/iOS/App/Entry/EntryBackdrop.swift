import PurlayDesign
import SwiftUI

/// The quiet field of brand blues behind Welcome. It drifts slowly: one way in `driftDuration`, then back. The points are worked
/// out from the time at most 15 times a second, a rate the slow drift cannot be told from a continuous one by, where letting
/// SwiftUI interpolate it drew every display frame (about 6 % CPU on an idle Welcome). It holds still under Reduce Motion and in
/// Low Power Mode.
struct EntryBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// When the field last began to drift, so a drift that starts or resumes starts at rest.
    @State private var driftStart = Date.now

    /// One way of the drift; it then returns. Slower than this would be invisible, faster would draw the eye.
    static let driftDuration: TimeInterval = 20
    /// How often the field is drawn while it drifts. At its fastest a point moves about a thousandth of the field a frame.
    static let frameInterval: TimeInterval = 1.0 / 15

    var body: some View {
        field
            .opacity(colorScheme == .dark ? 0.28 : 0.18)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .onChange(of: moves) { driftStart = .now }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                    lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
            }
    }

    private var moves: Bool { !reduceMotion && !lowPower }

    /// A timer's schedule rather than the display's: the field is drawn on its own beat and the display link stays idle.
    @ViewBuilder
    private var field: some View {
        if moves {
            TimelineView(.periodic(from: driftStart, by: Self.frameInterval)) { context in
                MeshGradient(
                    width: 3, height: 3, points: Self.points(after: context.date.timeIntervalSince(driftStart)),
                    colors: Self.colors)
            }
        } else {
            MeshGradient(width: 3, height: 3, points: Self.resting, colors: Self.colors)
        }
    }

    /// Where the points are a time after the drift began: from rest to drifted and back, easing in and out of each turn.
    static func points(after elapsed: TimeInterval) -> [SIMD2<Float>] {
        let phase = elapsed.truncatingRemainder(dividingBy: 2 * driftDuration) / driftDuration
        let way = phase <= 1 ? phase : 2 - phase
        let eased = Float(way * way * (3 - 2 * way))
        return zip(resting, drifted).map { rest, away in rest * (1 - eased) + away * eased }
    }

    /// The logo's own blues (`Logo`, from Design/purlay.svg), light to deep, so the field reads as the mark's colour.
    private static let colors: [Color] = [
        Logo.ribbonEnd, Logo.ribbonMiddle, Logo.stemEnd,
        Logo.ribbonMiddle, Logo.stemEnd, Logo.stemStart,
        Logo.stemEnd, Logo.stemStart, Logo.ribbonMiddle,
    ]

    /// The corners and the centre stay; the four points in the middle of the edges slide along their edges.
    static let resting: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.5, 0.5], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
    ]
    static let drifted: [SIMD2<Float>] = [
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
