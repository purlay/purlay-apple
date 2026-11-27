import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

/// Gaps the quality guardian found in the port of the old repositories (PR #8). Each fails until it is fixed.
@MainActor
@Suite("the port's gaps (quality guardian, PR #8)")
struct PortRecheckGapTests {
    /// iOS hides the engine's `.loadFailed` notice (`NoticeList.words`) because "the chat feed shows its own Try Again where
    /// messages did not load". The feed shows Try Again only from `channelLoadFailed`, and only while the channel has no
    /// window. A re-read of a channel already shown (Try Again, Jump to Latest when the window does not reach the newest) that
    /// fails leaves the window, sets no mark and says only `.loadFailed`: on iOS nothing at all is said.
    @Test("a failed re-read of a channel already shown leaves the channel's own mark, since iOS says no notice for it")
    func failedRereadIsMarked() async {
        let h = ModelHarness()
        await h.signedIn()
        let channel = Uuid(channel(2))!
        await h.model.showChannel(channel)
        #expect(h.model.chat.windows[channel] != nil)

        h.server.edit { $0.messagesStatus = 500 }
        await h.model.showChannel(channel)

        #expect(h.model.notices.contains { $0.kind == .loadFailed }, "the engine says it, but iOS hides this notice")
        #expect(
            h.model.channelLoadFailed.contains(channel),
            "nothing the iOS feed reads says that the re-read failed: the person is told nothing")
    }
}
