import SwiftUI

/// How much a button matters on its screen. One today: the action the screen exists for.
public enum ButtonRank: Sendable {
    case primary
}

extension View {
    /// A button of the given rank. From iOS 26 the system's prominent glass; before, the bordered prominent style.
    @ViewBuilder
    public func purlayButton(_ rank: ButtonRank) -> some View {
        switch rank {
        case .primary:
            if #available(iOS 26, macOS 26, *) {
                buttonStyle(.glassProminent).controlSize(.large).tint(Brand.accent)
            } else {
                buttonStyle(.borderedProminent).controlSize(.large).tint(Brand.accent)
            }
        }
    }

    /// A bar pinned to the bottom edge, over content that scrolls beneath it. From iOS 26 the system's scroll edge effect
    /// softens the content under it; before, the bar sits on a material.
    @ViewBuilder
    public func purlayBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26, macOS 26, *) {
            safeAreaBar(edge: .bottom) { bar() }
        } else {
            safeAreaInset(edge: .bottom) { bar().background(.bar) }
        }
    }

    /// How a notice arrives and leaves: from iOS 26 it materializes as glass; before, it slides in from the top.
    @ViewBuilder
    public func purlayNoticeTransition() -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffectTransition(.materialize)
        } else {
            transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Where notices stack. From iOS 26 they share one glass container, so glass notices blend and morph together.
public struct PurlayNoticeStack<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer { stack }
        } else {
            stack
        }
    }

    private var stack: some View {
        VStack(spacing: 8) { content }
    }
}

/// The button that closes a sheet without doing anything else, for a toolbar's cancellation place. From iOS 26 the system's close
/// button (an xmark, `role: .close`); before, the label as a plain toolbar button. Either way VoiceOver reads the label.
public struct PurlayCloseButton: View {
    private let label: Text
    private let action: () -> Void

    public init(_ label: Text, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        if #available(iOS 26, macOS 26, *) {
            Button(role: .close, action: action).accessibilityLabel(label)
        } else {
            Button(action: action) { label }
        }
    }
}
