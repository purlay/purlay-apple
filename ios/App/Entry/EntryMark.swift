import PurlayDesign
import SwiftUI

/// The one mark the entry screens share. It is drawn once, above the screens, and never inserted or removed: each screen only
/// says where it wants it (`EntryMarkSlot`), so the mark moves from one place to the next at full opacity while the screens
/// cross-fade beneath it.
enum EntryMark {
    static let id = "mark"
}

/// Where a screen wants the mark: an invisible stand-in of the mark's size, which the shared mark follows.
struct EntryMarkSlot: View {
    let brand: Namespace.ID

    var body: some View {
        Color.clear
            .frame(width: PurlayMark.launchSize, height: PurlayMark.launchSize)
            .matchedGeometryEffect(id: EntryMark.id, in: brand, isSource: true)
    }
}

extension View {
    /// Draws the shared mark over this view, following the `EntryMarkSlot` of the screen shown. Where no screen wants it, it
    /// fades out in place; it rests at the centre of the whole screen, where the launch screen puts it.
    func entryMark(in brand: Namespace.ID, shown: Bool) -> some View {
        overlay {
            PurlayMark()
                .matchedGeometryEffect(id: EntryMark.id, in: brand, isSource: false)
                .frame(width: PurlayMark.launchSize, height: PurlayMark.launchSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .purlayAnimation(.snappy, value: shown)
                .allowsHitTesting(false)
        }
    }
}
