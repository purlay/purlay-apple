import Foundation
import PurlayContract
import PurlayTestSupport
import Testing

@testable import PurlayKit

/// QA (PR #7 re-audit): gaps left after the fixes for I-1..I-5. Each test pins one and fails until the engine handles it.
@MainActor
@Suite("erasure and signing in again: what the re-audit found")
struct ErasureRecheckGapTests {
    private static let fresh = "fresh-session"
    private static let stranger = "0199155c-6200-7b7f-8c11-0000000000e9"

    private func desktop(_ h: ModelHarness) -> DesktopSessions {
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        return DesktopSessions(environment)
    }

    @Test(
        "after an unconfirmed erasure, a socket that says the session ended for a reason other than an erasure is not an erasure",
        arguments: ["signed-out", "expired"])
    func definiteReasonAfterUnconfirmed(reason: String) async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.eraseThrows = .timedOut }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .unconfirmed)
        // The server's own word: this session was signed out (or expired), so it was alive after the request, and an
        // erased account's sockets are told `account-deleted`, never this.
        h.last.handlers.message(#"{"event":"SESSION_ENDED","ts":1,"data":{"reason":"\#(reason)"}}"#)
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(wiper.wipes == 0, "the account still exists: its drafts and outbox wait for the next sign-in")
        #expect(
            h.model.notices.map(\.kind) != [.accountPossiblyErased],
            "told 'your account was probably deleted' when the server said otherwise: \(h.model.notices.map(\.kind))")
    }

    @Test("an unconfirmed erasure is still unconfirmed after the app is quit and opened again: no 'sign in again'")
    func unconfirmedSurvivesRelaunch() async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.eraseThrows = .timedOut }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .unconfirmed)
        // The person quits the app that hung; the erasure had gone through, and every session with it.
        h.server.edit {
            $0.eraseThrows = nil
            $0.sessionValid = false
        }
        let relaunched = AppModel(h.model.environment)
        await relaunched.connect()
        await h.settle()
        #expect(relaunched.phase == .signedOut)
        #expect(
            !relaunched.notices.map(\.kind).contains(.sessionEndedByServer),
            "told to sign in again, which makes a new account: \(relaunched.notices.map(\.kind))")
        #expect(wiper.wipes == 1, "the probably erased person's drafts and outbox stay on the device")
    }

    @Test("on the Mac, signing in again in one workspace does not sign the person out of every workspace of the server")
    func reauthenticateKeepsOtherWorkspaces() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        #expect(first.phase == .ready && studio.phase == .ready)
        h.server.edit { $0.nextSession = Self.fresh }
        #expect(await first.reauthenticate() == .done)
        // The other workspace still holds the session that was just ended: its next read (or the old session's
        // SESSION_ENDED on its socket) is refused.
        await studio.refreshAccount()
        await h.settle()
        #expect(first.phase == .ready, "the workspace that signed in again was signed out by its sibling")
        #expect(studio.phase == .ready, "the person signed in again as themselves and lost every other workspace")
        #expect(
            first.notices.isEmpty && studio.notices.isEmpty,
            "\(first.notices.map(\.kind)) \(studio.notices.map(\.kind))")
    }

    @Test("on the Mac, signing out of a workspace held by another person does not remove the first person's data")
    func otherPersonsWorkspaceKeepsItsData() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        _ = await studio.signOut(.thisDevice)
        await h.settle()
        #expect(first.phase == .signedOut && studio.phase == .signedOut)
        // Ada signs in again in her workspace and writes a draft; the other workspace's window is signed in by somebody else.
        await first.signIn()
        #expect(first.phase == .ready)
        let place = try #require(Uuid(channel(1)))
        first.setDraft("ada's draft", for: place)
        h.server.edit {
            $0.nextSession = Self.fresh
            $0.userIDBySession[Self.fresh] = Self.stranger
        }
        await studio.signIn()
        #expect(studio.phase == .ready)
        #expect(studio.me?.user.id.value == Self.stranger)
        #expect(first.me?.user.id.value == FakeServer.userID)
        _ = await studio.signOut(.thisDevice)
        await h.settle()
        let adasDraft = Drafts.key(user: try #require(Uuid(FakeServer.userID)), channel: place, parent: nil)
        #expect(
            first.environment.preferences.string(for: adasDraft) == "ada's draft",
            "another person's sign-out removed Ada's draft")
    }
}
