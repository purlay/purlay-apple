import SwiftUI

/// Centres its content when it fits and scrolls when it does not (a large Dynamic Type size), instead of clipping.
struct Scrolling<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content.frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
