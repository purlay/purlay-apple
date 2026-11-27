import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// QA (PR #7): the races and signals around an erasure that `AccountErasureTests` does not cover. Each test pins a gap found
/// by the quality audit; they fail until the engine handles it.
@MainActor
@Suite("erasing the account: races and the server's own word")
struct AccountErasureGapTests {
    private static let accountDeleted = #"{"event":"SESSION_ENDED","ts":1,"data":{"reason":"account-deleted"}}"#

    @Test(
        "an account erased from another device (the socket says account-deleted) is wiped here and said as an erasure")
    func erasedElsewhere() async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.last.handlers.message(Self.accountDeleted)
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(wiper.wipes == 1, "an erased account has no next sign-in to keep its data for")
        #expect(h.model.notices.map(\.kind) == [.accountErased], "\(h.model.notices.map(\.kind))")
    }

    @Test(
        "an answer lost after the server erased (its socket said account-deleted) is still an erasure, not 'sign in and try again'"
    )
    func answerLostAfterCommit() async throws {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        let socket = h.last
        let sessions = h.sessions
        let server = try ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)
        h.server.edit {
            // The server committed and told the socket; the proxy in front of it then timed out the HTTP answer.
            $0.eraseStatus = 504
            $0.eraseError = #"{"error":{"code":"INTERNAL","message":"x"}}"#
            $0.beforeEraseResponse = {
                await MainActor.run { socket.handlers.message(Self.accountDeleted) }
                while (try? sessions.load(for: server)) != nil { await Task.yield() }
                for _ in 0..<20 { await MainActor.run {} }
            }
        }
        let result = await h.model.eraseAccount(confirmation: "ada")
        await h.settle()
        #expect(
            result == .erased,
            "got \(result), notices \(h.model.notices.map(\.kind)); the words for .sessionEnded tell the person to sign in again, which makes a new account"
        )
        #expect(wiper.wipes == 1)
        #expect(h.model.notices.map(\.kind) == [.accountErased])
    }

    @Test("a sign-out asked while an erasure is out runs every wiper once, not twice, and ends the session once")
    func signOutDuringErase() async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        var ended = 0
        h.model.onSessionEnded = { ended += 1 }
        let model = h.model!
        let signOut = Mutex<Task<SessionManager.SignOutResult, Never>?>(nil)
        h.server.edit {
            // Asked while the erasure waits for its answer; not awaited here, since the sign-out waits for the erasure.
            $0.beforeEraseResponse = {
                let run = Task { @MainActor in await model.signOut(.thisDevice) }
                signOut.withLock { $0 = run }
                for _ in 0..<20 { await MainActor.run {} }
            }
        }
        _ = await h.model.eraseAccount(confirmation: "ada")
        _ = await signOut.withLock { $0 }?.value
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(wiper.wipes == 1, "wiped \(wiper.wipes) times")
        #expect(ended == 1, "ended \(ended) times")
    }
}
