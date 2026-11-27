import PurlayKit
import PurlayWords
import Testing

@testable import Purlay

/// What a notice says on iOS: the engine's words, as on the Mac, except where a screen of this app already says it.
@Suite("what a notice says on iOS")
struct NoticeWordsTests {
    @Test("messages that did not load are said by the chat feed's own Try Again, not by a notice as well")
    func loadFailedIsTheFeeds() {
        #expect(NoticeList.words(.loadFailed) == nil)
    }

    @Test(
        "every other notice says the engine's words, as the Mac does",
        arguments: [
            Notice.Kind.readFailed, .sessionExpired, .serverNotTold, .signOutEverywhereFailed, .signOutFailed,
        ])
    func othersAreTheEngines(kind: Notice.Kind) {
        #expect(NoticeList.words(kind) != nil)
        #expect(NoticeList.words(kind) == EngineWords.notice(kind))
    }
}
