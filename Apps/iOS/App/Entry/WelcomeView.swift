import PurlayDesign
import SwiftUI

/// Signed out: who Purlay is, and the one thing to do. The shared mark (`entryMark`) arrives from the connecting screen; Sign In stands in the
/// bottom bar with where the sign-in continues said under it, and the mark is never drawn over the bar (`entryMarkFloor`).
struct WelcomeView: View {
    /// The host the browser will open, when the server is known.
    let server: String?
    let brand: Namespace.ID
    let signIn: () async -> Void

    /// The tagline's and the footer's colour: the muted ink token, readable (4.5:1 and more) on the tinted field in light and
    /// dark, where `.secondary` measured 3.3:1 in light.
    static let quietInk = Brand.inkMuted

    /// Wide enough for the button to read as the screen's action on an iPhone, and no wider on a large window.
    private static let barWidth: CGFloat = 480

    var body: some View {
        Scrolling {
            RaisedGroupLayout {
                hero
                Text(Words.newAccount)
                    .font(.footnote)
                    .foregroundStyle(Self.quietInk)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .purlayBottomBar { bar.entryMarkFloor() }
        .background { EntryBackdrop() }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            EntryMarkSlot(brand: brand)
            VStack(spacing: 8) {
                Text(verbatim: "Purlay").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text(Words.tagline).font(.title3).foregroundStyle(Self.quietInk)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var bar: some View {
        VStack(spacing: 12) {
            Button {
                Task { await signIn() }
            } label: {
                Text(Words.signInButton).frame(maxWidth: .infinity)
            }
            .purlayButton(.primary)
            Text(server.map(Words.continuesInBrowser) ?? Words.continuesInBrowserNoHost)
                .font(.footnote)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                // The bar is offered only the height left over, which in landscape at a large text size is less than the
                // sentence needs: it takes its whole height and wraps instead of ending in "…".
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: Self.barWidth)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

/// The group over the footer, with the group's centre a little above the middle of the space (at 40 % of the height) so it
/// does not sink towards the bar, and the footer at the bottom. A share of the height rather than padding, so it holds on every
/// screen; when the two outgrow the space they stack and the layout grows, so the content scrolls instead of clipping.
private struct RaisedGroupLayout: Layout {
    private static let groupCentre: CGFloat = 0.4
    private static let spacing: CGFloat = 32

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
        let stacked = sizes.map(\.height).reduce(0, +) + Self.spacing * CGFloat(max(sizes.count - 1, 0))
        let width = proposal.width ?? sizes.map(\.width).max() ?? 0
        return CGSize(width: width, height: max(proposal.height ?? 0, stacked))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard let group = subviews.first, let footer = subviews.last, subviews.count == 2 else { return }
        let width = ProposedViewSize(width: bounds.width, height: nil)
        let groupHeight = group.sizeThatFits(width).height
        let footerHeight = footer.sizeThatFits(width).height
        let lowestTop = bounds.maxY - footerHeight - Self.spacing - groupHeight
        let groupTop = min(
            max(bounds.minY, bounds.minY + bounds.height * Self.groupCentre - groupHeight / 2), lowestTop)
        group.place(at: CGPoint(x: bounds.midX, y: max(groupTop, bounds.minY)), anchor: .top, proposal: width)
        footer.place(at: CGPoint(x: bounds.midX, y: bounds.maxY), anchor: .bottom, proposal: width)
    }
}

#Preview("Light") {
    @Previewable @Namespace var brand
    WelcomeView(server: "purlay.app", brand: brand, signIn: {}).entryMark(in: brand, shown: true)
}

#Preview("Dark") {
    @Previewable @Namespace var brand
    WelcomeView(server: "purlay.app", brand: brand, signIn: {}).entryMark(in: brand, shown: true).preferredColorScheme(
        .dark)
}

#Preview("Turkish") {
    @Previewable @Namespace var brand
    WelcomeView(server: "sohbet.örnek.com.tr", brand: brand, signIn: {}).entryMark(in: brand, shown: true).environment(
        \.locale, .init(identifier: "tr"))
}

#Preview("Largest text, no host") {
    @Previewable @Namespace var brand
    WelcomeView(server: nil, brand: brand, signIn: {}).entryMark(in: brand, shown: true).dynamicTypeSize(
        .accessibility5)
}

#Preview("375 pt, largest text", traits: .fixedLayout(width: 375, height: 667)) {
    @Previewable @Namespace var brand
    WelcomeView(server: "purlay.app", brand: brand, signIn: {}).entryMark(in: brand, shown: true)
        .dynamicTypeSize(.accessibility5)
}
