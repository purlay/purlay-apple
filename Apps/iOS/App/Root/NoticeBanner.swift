import PurlayDesign
import PurlayWords
import SwiftUI

/// One thing the model said that is not a screen of its own, to be dismissed. It stays a notice at every text size: past a few
/// lines the rest is behind Read More, which shows the whole sentence in a sheet (VoiceOver reads the whole sentence either
/// way), so it never covers the screen it is about.
struct NoticeBanner: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let words: LocalizedStringResource
    let dismiss: () -> Void

    @State private var reading = false
    /// The sentence's height in full and as shown, at the banner's width: when they differ, there is more to show.
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0

    static let verticalPadding: CGFloat = 12
    static let minimumTarget: CGFloat = 44
    /// The dismiss glyph's ink. The tint is the accent, a fill colour: 1.9:1 on the dark glass, under the 3:1 a control's glyph
    /// needs. The token for icons and text keeps it above that on the glass in light and dark.
    static let dismissInk = Brand.accentText
    /// A single line's banner is a capsule; a taller one keeps these corners, so its text is never cut by the curve.
    private static let cornerRadius: CGFloat = 26

    /// How many lines show before Read More: three, or one where a landscape iPhone has little height to give.
    static func collapsedLineLimit(_ verticalSizeClass: UserInterfaceSizeClass?) -> Int {
        verticalSizeClass == .compact ? 1 : 3
    }

    private var isTruncated: Bool { fullHeight > shownHeight + 1 }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                sentence
                if isTruncated { readMore }
            }
            .padding(.vertical, Self.verticalPadding)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(Self.dismissInk)
                    .frame(minWidth: Self.minimumTarget, minHeight: Self.minimumTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text(EngineWords.dismiss))
            .accessibilityIdentifier("notice.dismiss")
            // Clear of the corner's curve, which is wide at a large text size.
            .padding(.top, 4)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .purlaySurface(.panel, in: .rect(cornerRadius: Self.cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $reading) { WholeNotice(words: words) }
    }

    private var sentence: some View {
        Text(words)
            .font(.callout)
            .lineLimit(Self.collapsedLineLimit(verticalSizeClass))
            // Its lines are always shown, however little height the screen offers.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Self.minimumTarget - 2 * Self.verticalPadding, alignment: .leading)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { shownHeight = $0 }
            // The same sentence at the same width with no limit, unseen, to learn whether the limit cut it.
            .background(alignment: .top) {
                Text(words)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { fullHeight = $0 }
            }
    }

    private var readMore: some View {
        Button {
            reading = true
        } label: {
            Text(Words.readMore)
                .font(.callout.weight(.semibold))
                .frame(minHeight: Self.minimumTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("notice.expand")
    }
}

/// The whole of a notice, in a sheet that scrolls: a banner has no height to give it at a large text size or in landscape.
private struct WholeNotice: View {
    @Environment(\.dismiss) private var close
    let words: LocalizedStringResource

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(words)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        close()
                    } label: {
                        Text(EngineWords.dismiss)
                    }
                    .accessibilityIdentifier("notice.whole.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
