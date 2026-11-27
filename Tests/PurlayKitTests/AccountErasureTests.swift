import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

/// P-1: a person erases their own account from the app (`POST /api/me/erase`, App Store Guideline 5.1.1(v)). The answer is a
/// value the screen acts on; an erased account is signed out here as a sign-out is, with every wiper run once.
@MainActor
@Suite("erasing the account")
struct AccountErasureTests {
    private static let erasePath = "/api/me/erase"

    private func erases(_ h: ModelHarness) -> [HTTPRequest] {
        h.server.requests.filter { $0.url.path == Self.erasePath }
    }

    private func error(_ code: String, details: String? = nil) -> String {
        let more = details.map { ",\"details\":\($0)" } ?? ""
        return "{\"error\":{\"code\":\"\(code)\",\"message\":\"x\"\(more)}}"
    }

    @Test("an account erased signs out here: the credential, the socket and every wiper go, and the person is told")
    func erased() async throws {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        #expect(await h.model.eraseAccount(confirmation: "ada") == .erased)
        let request = try #require(erases(h).first)
        #expect(request.method == "POST")
        let body = try JSONDecoder().decode(EraseAccountRequest.self, from: try #require(request.body))
        #expect(body.confirm == "ada")
        #expect(h.model.phase == .signedOut)
        #expect(h.model.notices.map(\.kind) == [.accountErased])
        #expect(wiper.wipes == 1)
        #expect(h.last.closedByClient)
        #expect(h.model.me == nil)
        #expect(try h.sessions.load(for: try ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)) == nil)
        #expect(h.owner.load() == nil)
        #expect(!h.server.requests.contains { $0.url.path.hasPrefix("/auth/logout") }, "the server ended it itself")
    }

    @Test(
        "a confirmation that is not the username is refused here, and the server is not asked",
        arguments: [
            "", "Ada", "ada ", " ada", "grace",
        ])
    func mismatchHere(confirmation: String) async {
        let h = ModelHarness()
        await h.signedIn()
        #expect(await h.model.eraseAccount(confirmation: confirmation) == .confirmationMismatch)
        #expect(erases(h).isEmpty)
        #expect(h.model.phase == .ready)
    }

    @Test(
        "each refusal of the server is a value the screen acts on, and the person stays signed in",
        arguments: [
            (403, "REAUTHENTICATION_REQUIRED", EraseAccountResult.reauthenticationRequired),
            (400, "VALIDATION_FAILED", .confirmationMismatch),
            (403, "FORBIDDEN", .refused),
            (403, "TWO_FACTOR_REQUIRED", .refused),
            (429, "RATE_LIMITED", .failed),
            (500, "INTERNAL", .failed),
            (503, "DATABASE_UNAVAILABLE", .failed),
        ])
    func refusals(status: Int, code: String, expected: EraseAccountResult) async {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit {
            $0.eraseStatus = status
            $0.eraseError = error(code)
        }
        #expect(await h.model.eraseAccount(confirmation: "ada") == expected)
        #expect(h.model.phase == .ready)
        #expect(h.model.notices.isEmpty, "\(h.model.notices.map(\.kind))")
        #expect(wiper.wipes == 0)
        #expect(erases(h).count == 1, "a refused erasure is not sent again by itself")
    }

    @Test("the last owner of a workspace with other people is told which workspaces to hand over")
    func lastOwner() async {
        let h = ModelHarness()
        await h.signedIn()
        let other = "0199155c-6200-7b7f-8c11-0000000000bb"
        h.server.edit {
            $0.eraseStatus = 409
            $0.eraseError = error(
                "LAST_OWNER", details: "{\"workspaceIds\":[\"\(FakeServer.workspaceID)\",\"\(other)\"]}")
        }
        let result = await h.model.eraseAccount(confirmation: "ada")
        #expect(result == .lastOwner(workspaceIDs: [Uuid(FakeServer.workspaceID)!, Uuid(other)!]))
        #expect(h.model.phase == .ready)
    }

    @Test("a last-owner refusal without its details is still a last-owner refusal, naming none")
    func lastOwnerWithoutDetails() async {
        let h = ModelHarness()
        await h.signedIn()
        h.server.edit {
            $0.eraseStatus = 409
            $0.eraseError = error("LAST_OWNER")
        }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .lastOwner(workspaceIDs: []))
    }

    @Test("with no network nothing is erased and nothing is removed here")
    func offline() async {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.online = false }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .failed)
        #expect(h.model.phase == .ready)
        #expect(wiper.wipes == 0)
    }

    @Test("a session the server ended meanwhile is a sign-out, said as the server's, and nothing is wiped")
    func sessionEnded() async {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.sessionValid = false }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .sessionEnded)
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(h.model.notices.map(\.kind) == [.sessionEndedByServer])
        #expect(wiper.wipes == 0)
    }

    @Test("signed out, there is nothing to erase and the server is not asked")
    func signedOut() async {
        let h = ModelHarness()
        await h.model.connect()
        #expect(await h.model.eraseAccount(confirmation: "ada") == .sessionEnded)
        #expect(erases(h).isEmpty)
    }

    @Test("two quick erasures ask the server once and share its answer")
    func once() async {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        async let first = h.model.eraseAccount(confirmation: "ada")
        async let second = h.model.eraseAccount(confirmation: "ada")
        let results = await [first, second]
        #expect(results == [.erased, .erased])
        #expect(erases(h).count == 1)
        #expect(wiper.wipes == 1)
        #expect(h.model.notices.map(\.kind) == [.accountErased])
    }

    @Test("the socket's SESSION_ENDED arriving before the answer is the erasure's: erased, wiped, and said once")
    func socketFirst() async throws {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        let socket = h.last
        let sessions = h.sessions
        let server = try ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)
        h.server.edit {
            $0.beforeEraseResponse = {
                await MainActor.run {
                    socket.handlers.message(#"{"event":"SESSION_ENDED","ts":1,"data":{"reason":"account-deleted"}}"#)
                }
                // The frame has ended the session (its credential is gone) before the answer leaves, and the main actor has
                // had its turns to hear of it.
                while (try? sessions.load(for: server)) != nil { await Task.yield() }
                for _ in 0..<20 { await MainActor.run {} }
            }
        }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .erased)
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(h.model.notices.map(\.kind) == [.accountErased])
        #expect(wiper.wipes == 1)
    }

    @Test("a conversation window erases through the window that owns the session")
    func fromConversationWindow() async throws {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        let request = try #require(h.model.conversationWindowRequest(for: Uuid(channel(1))!))
        let window = try #require(await h.model.makeConversationWindow(request))
        #expect(await window.eraseAccount(confirmation: "ada") == .erased)
        #expect(h.model.phase == .signedOut)
        #expect(window.phase == .signedOut)
        #expect(erases(h).count == 1)
        #expect(wiper.wipes == 1)
    }
}
