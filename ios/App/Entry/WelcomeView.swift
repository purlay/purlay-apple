import PurlayDesign
import SwiftUI

/// Signed out: who Purlay is, and the one thing to do. The mark arrives from the connecting screen; Sign In stands in the
/// bottom bar with where the sign-in continues said under it.
struct WelcomeView: View {
    /// The host the browser will open, when the server is known.
    let server: String?
    let brand: Namespace.ID
    let signIn: () async -> Void

    /// Wide enough for the button to read as the screen's action on an iPhone, and no wider on a large window.
    private static let barWidth: CGFloat = 480

    var body: some View {
        Scrolling {
            VStack(spacing: 32) {
                Spacer(minLength: 0)
                hero
                Spacer(minLength: 0)
                Text(Words.newAccount)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .purlayBottomBar { bar }
        .background { EntryBackdrop() }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            PurlayMark()
                .matchedGeometryEffect(id: EntryMark.id, in: brand)
                .frame(width: PurlayMark.launchSize, height: PurlayMark.launchSize)
            VStack(spacing: 8) {
                Text(verbatim: "Purlay").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text(Words.tagline).font(.title3).foregroundStyle(.secondary)
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
        }
        .frame(maxWidth: Self.barWidth)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview("Light") {
    @Previewable @Namespace var brand
    WelcomeView(server: "purlay.app", brand: brand, signIn: {})
}

#Preview("Dark") {
    @Previewable @Namespace var brand
    WelcomeView(server: "purlay.app", brand: brand, signIn: {}).preferredColorScheme(.dark)
}

#Preview("Turkish") {
    @Previewable @Namespace var brand
    WelcomeView(server: "sohbet.örnek.com.tr", brand: brand, signIn: {}).environment(\.locale, .init(identifier: "tr"))
}

#Preview("Largest text, no host") {
    @Previewable @Namespace var brand
    WelcomeView(server: nil, brand: brand, signIn: {}).dynamicTypeSize(.accessibility5)
}
