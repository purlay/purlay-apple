import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

/// FR-222 says words from outside a box send nothing while a sign-out holds sends: the person accepted that what is unsent is
/// removed, so a notice's reply or a shortcut that arrives during the confirmation must not be queued behind it.
@MainActor
@Suite("words from outside a box while a sign-out holds sends")
struct OutsidePostingHoldTests {
    @Test("nothing is posted while a sign-out holds sends, and posting works again once it is released")
    func heldBySignOut() async throws {
        let h = ModelHarness()
        await h.signedIn()
        await h.settle()
        let other = try #require(Uuid(channel(2)))
        let hold = UUID()
        h.model.holdSends(for: hold, stoppingEngine: false)
        #expect(!h.model.canPost(to: other, parent: nil))
        #expect(!h.model.post("during the sign-out", to: other))
        h.model.releaseSends(for: hold)
        #expect(h.model.post("after it", to: other))
        let contents = h.last.sent.filter { $0.contains("MESSAGE_SEND") }
        #expect(contents.count == 1)
        #expect(contents.allSatisfy { !$0.contains("during the sign-out") })
    }
}
