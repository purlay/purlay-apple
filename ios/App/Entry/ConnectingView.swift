import PurlayDesign
import SwiftUI

/// Something is under way. The shared mark (`entryMark`) stands exactly where the launch screen put it, so the launch flows into the app without a
/// blink; what is under way is said under it only after a moment, so a fast connection shows nothing but the mark.
struct ConnectingView: View {
    let busy: RootScreen.Busy
    let brand: Namespace.ID

    @State private var showsStatus = false

    /// How long a connection may take before it is worth saying what is under way.
    private static let statusDelay = Duration.milliseconds(500)

    var body: some View {
        VStack(spacing: 24) {
            EntryMarkSlot(brand: brand)
                .alignmentGuide(.markCenter) { $0[VerticalAlignment.center] }
            status
        }
        .padding(.horizontal)
        // Centred on the whole screen, safe areas ignored, as the launch screen centres its image.
        .frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: .center, vertical: .markCenter)
        )
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: Self.statusDelay)
            showsStatus = true
        }
    }

    private var status: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(words).font(.headline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        // Kept in the layout while hidden, so its arrival moves nothing.
        .opacity(showsStatus ? 1 : 0)
        .accessibilityHidden(!showsStatus)
        .purlayAnimation(.smooth, value: showsStatus)
    }

    private var words: LocalizedStringResource {
        switch busy {
        case .connecting: Words.connecting
        case .signingIn: Words.waitingForBrowser
        case .loading: Words.loadingWorkspace
        }
    }
}

extension VerticalAlignment {
    /// The mark's centre, so a screen can centre the mark rather than the mark and what stands under it.
    fileprivate enum MarkCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat { dimensions[VerticalAlignment.center] }
    }

    fileprivate static let markCenter = VerticalAlignment(MarkCenter.self)
}

#Preview("Light") {
    @Previewable @Namespace var brand
    ConnectingView(busy: .connecting, brand: brand).entryMark(in: brand, shown: true)
}

#Preview("Dark") {
    @Previewable @Namespace var brand
    ConnectingView(busy: .signingIn, brand: brand).entryMark(in: brand, shown: true).preferredColorScheme(.dark)
}

#Preview("Turkish") {
    @Previewable @Namespace var brand
    ConnectingView(busy: .loading, brand: brand).entryMark(in: brand, shown: true).environment(
        \.locale, .init(identifier: "tr"))
}

#Preview("Largest text") {
    @Previewable @Namespace var brand
    ConnectingView(busy: .signingIn, brand: brand).entryMark(in: brand, shown: true).dynamicTypeSize(.accessibility5)
}
