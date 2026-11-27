import PurlayDesign
import SwiftUI

/// The one mark the entry screens share. It is drawn once, above the screens, and never inserted or removed: each screen only
/// says where it wants it (`EntryMarkSlot`), so the mark moves from one place to the next at full opacity while the screens
/// cross-fade beneath it.
enum EntryMark {
    static let id = "mark"
}

/// Where a screen wants the mark: an invisible stand-in of the mark's size, which the shared mark follows.
///
/// Under Reduce Motion the shared mark is hidden and each slot draws the mark itself, so the mark does not travel between
/// screens: it fades out in the old place and in at the new one, with the screens' cross-fade.
struct EntryMarkSlot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let brand: Namespace.ID

    var body: some View {
        Color.clear
            .frame(width: PurlayMark.launchSize, height: PurlayMark.launchSize)
            .matchedGeometryEffect(id: EntryMark.id, in: brand, isSource: true)
            // Outside the matched effect: a slot that arrives is moved from where the old one was, and this mark must not be.
            .overlay {
                if reduceMotion { PurlayMark() }
            }
    }
}

extension View {
    /// Draws the shared mark over this view, following the `EntryMarkSlot` of the screen shown. Where no screen wants it, it
    /// fades out in place; it rests at the centre of the whole screen, where the launch screen puts it.
    func entryMark(in brand: Namespace.ID, shown: Bool) -> some View {
        overlayPreferenceValue(EntryMarkFloor.self) { floor in
            EntryMarkOverlay(brand: brand, shown: shown, floor: floor)
        }
    }

    /// Marks this view as a bar the shared mark goes under: content scrolled beneath it takes the mark with it, and the mark
    /// is cut at the bar's top edge instead of drawn over its controls.
    func entryMarkFloor() -> some View {
        anchorPreference(key: EntryMarkFloor.self, value: .bounds) { $0 }
    }
}

/// The bounds of the bar the shown screen keeps at its bottom, if it has one.
private struct EntryMarkFloor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private struct EntryMarkOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let brand: Namespace.ID
    let shown: Bool
    let floor: Anchor<CGRect>?

    var body: some View {
        // Read inside the safe area, so the mark can be kept out of the status bar while it is centred on the whole screen.
        GeometryReader { proxy in
            PurlayMark()
                .matchedGeometryEffect(id: EntryMark.id, in: brand, isSource: false)
                .frame(width: PurlayMark.launchSize, height: PurlayMark.launchSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                // Content scrolled under the status bar or the bottom bar takes the mark with it; it is cut off at their
                // edges instead of drawn over the clock, the Dynamic Island or Sign In. At rest it is clear of both.
                .mask {
                    Rectangle()
                        .padding(.top, proxy.safeAreaInsets.top)
                        .padding(.bottom, Self.belowFloor(floor.map { proxy[$0].minY }, in: proxy))
                        .ignoresSafeArea()
                }
        }
        // Under Reduce Motion the slots draw the mark (see `EntryMarkSlot`), so this one would only travel.
        .opacity(shown && !reduceMotion ? 1 : 0)
        .purlayAnimation(.snappy, value: shown)
        .allowsHitTesting(false)
    }

    /// How much of the whole screen lies below the bar's top edge (given in the safe area's coordinates); none without a bar.
    private static func belowFloor(_ floorTop: CGFloat?, in proxy: GeometryProxy) -> CGFloat {
        guard let floorTop else { return 0 }
        return max(0, proxy.size.height + proxy.safeAreaInsets.bottom - floorTop)
    }
}
