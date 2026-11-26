import PurlayKit
import PurlayWords
import SwiftUI
import Testing
import UIKit

@testable import Purlay

@MainActor
@Suite("a notice stays a notice at the largest text size")
struct NoticeBannerTests {
    /// An iPhone's width in portrait, where a notice has the least room across.
    private static let width: CGFloat = 402
    private static let largest = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

    private func height(of banner: NoticeBanner, at size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: banner.dynamicTypeSize(size))
        return host.sizeThatFits(in: CGSize(width: Self.width, height: .greatestFiniteMagnitude)).height
    }

    @Test("a long notice shows about three lines, not half the screen, at the largest accessibility size")
    func compactAtTheLargestSize() throws {
        let words = try #require(EngineWords.notice(.storageProblem))
        let line = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: Self.largest).lineHeight
        let banner = height(of: NoticeBanner(words: words, dismiss: {}), at: .accessibility5)
        // Three lines of the sentence, one for the control that shows the rest, and the banner's padding above and below.
        #expect(banner <= 4 * line + 2 * NoticeBanner.verticalPadding + 1, "a notice \(banner) pt tall")
    }

    // A landscape iPhone hides the status bar and leaves no top safe area: the notice would touch the screen's edge.
    @Test("in landscape a notice keeps a margin from the top edge; in portrait the status bar gives it one")
    func landscapeMargin() {
        #expect(NoticeList.topMargin(.compact) >= 8)
        #expect(NoticeList.topMargin(.regular) == 0)
    }

    @Test("a short notice is one line with its dismiss button, a 44 pt target, beside it")
    func shortNoticeIsOneLine() {
        let banner = height(of: NoticeBanner(words: "Saved.", dismiss: {}), at: .large)
        #expect(banner >= NoticeBanner.minimumTarget)
        #expect(banner < 2 * NoticeBanner.minimumTarget)
    }
}
