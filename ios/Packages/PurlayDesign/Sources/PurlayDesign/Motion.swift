import SwiftUI

/// How a change moves, named by feel. Features pick one and never write a spring, so Reduce Motion is honoured in one place.
public enum Motion: Sendable {
    /// A view arriving, leaving or settling.
    case smooth
    /// A control answering a touch.
    case snappy

    /// With Reduce Motion every movement becomes a short fade, which keeps the change visible without the travel.
    public func animation(reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeInOut(duration: 0.15) }
        switch self {
        case .smooth: return .smooth
        case .snappy: return .snappy
        }
    }
}

extension View {
    /// Animates changes of `value` with `motion`, softened when the person has asked for Reduce Motion.
    public func purlayAnimation<Value: Equatable>(_ motion: Motion, value: Value) -> some View {
        modifier(MotionModifier(motion: motion, value: value))
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: Motion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
    }
}
