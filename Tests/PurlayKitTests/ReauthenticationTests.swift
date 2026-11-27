import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// FR-217: erasing the account needs a sign-in within `ERASURE_SIGN_IN_MINUTES`. A person signed in for longer signs in again
/// through the browser, as at first: the same person keeps everything they had here on a new session, and the old one ends.
@MainActor
@Suite("signing in again while signed in")
struct ReauthenticationTests {
    private static let fresh = "fresh-session"
    private static let stranger = "0199155c-6200-7b7f-8c11-0000000000e9"
    private let server = try! ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)

    private func logouts(_ h: ModelHarness) -> [String?] {
        h.server.requests.filter { $0.url.path == "/auth/logout" }.map { $0.headers["Cookie"] }
    }

    private func cookie(_ value: String) -> String { "__Host-purlay_session=\(value)" }

    @Test("the same person signed in again keeps everything here on the new session, and the old session is ended")
    func samePerson() async throws {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        let place = try #require(Uuid(channel(1)))
        h.model.setDraft("half written", for: place)
        h.server.edit { $0.nextSession = Self.fresh }
        #expect(await h.model.reauthenticate() == .done)
        #expect(h.model.phase == .ready)
        #expect(wiper.wipes == 0)
        #expect(h.model.draft(for: place) == "half written")
        #expect(try h.sessions.load(for: server)?.cookie == Self.fresh)
        #expect(logouts(h) == [cookie(FakeServer.sessionValue)], "the old session, and only it, is ended")
        #expect(h.openedWith.last == Self.fresh, "the socket opens again on the new session")
        await h.model.refreshAccount()
        let read = try #require(h.server.requests.last { $0.url.path == "/api/me" })
        #expect(read.headers["Cookie"] == cookie(Self.fresh))
        #expect(h.model.phase == .ready)
        #expect(h.model.notices.isEmpty, "\(h.model.notices.map(\.kind))")
    }

    @Test("the old session's end, said on its old socket, does not sign the person out of the new one")
    func oldSocketIgnored() async {
        let h = ModelHarness()
        await h.signedIn()
        let old = h.last
        h.server.edit { $0.nextSession = Self.fresh }
        #expect(await h.model.reauthenticate() == .done)
        old.handlers.message(#"{"event":"SESSION_ENDED","ts":1,"data":{"reason":"signed-out"}}"#)
        await h.settle()
        #expect(h.model.phase == .ready)
        #expect(h.model.notices.isEmpty)
    }

    @Test("a browser that signed in somebody else changes nothing here, and that session is ended at once")
    func differentPerson() async throws {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.elapsed.set(TimeInterval(ContractConstants.erasureSignInMinutes * 60))
        h.server.edit {
            $0.nextSession = Self.fresh
            $0.userIDBySession[Self.fresh] = Self.stranger
        }
        #expect(await h.model.reauthenticate() == .differentPerson)
        #expect(h.model.phase == .ready)
        #expect(h.model.me?.user.id.value == FakeServer.userID)
        #expect(try h.sessions.load(for: server)?.cookie == FakeServer.sessionValue)
        #expect(logouts(h) == [cookie(Self.fresh)])
        #expect(wiper.wipes == 0)
        #expect(h.model.erasureNeedsReauthentication, "nothing more recent was gained")
    }

    @Test("a sign-in the person closed changes nothing and ends nothing")
    func cancelled() async throws {
        let opened = Mutex(0)
        let browser = ScriptedBrowser { page in
            // The first opening signs in; the second is closed by the person.
            let count = opened.withLock { count in
                count += 1
                return count
            }
            if count > 1 { throw WebAuthenticatorError.cancelled }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let h = ModelHarness(browser: browser)
        await h.signedIn()
        #expect(await h.model.reauthenticate() == .failed(.cancelled))
        #expect(h.model.phase == .ready)
        #expect(logouts(h).isEmpty)
        #expect(try h.sessions.load(for: server)?.cookie == FakeServer.sessionValue)
    }

    @Test("signed out, there is nobody to sign in again, and the browser is not opened")
    func notSignedIn() async {
        let h = ModelHarness()
        await h.model.connect()
        #expect(await h.model.reauthenticate() == .notSignedIn)
        #expect(!h.server.requests.contains { $0.url.path == "/api/native/token" })
    }

    @Test("signing in while signed in opens no browser: a second session would be adopted, the first not ended")
    func signInWhileReady() async {
        let h = ModelHarness()
        await h.signedIn()
        let before = h.server.requests.count { $0.url.path == "/api/native/token" }
        await h.model.signIn()
        #expect(h.server.requests.count { $0.url.path == "/api/native/token" } == before)
        #expect(h.model.phase == .ready)
    }

    @Test(
        "on the Mac, a browser sign-in's session is kept only once /api/me says whose it is, and Try Again reads with it"
    )
    func keptOnlyOnceKnown() async throws {
        let h = ModelHarness()
        // A model with other sessions of its server to answer to, as each of the Mac's workspaces has.
        h.model.sharedServer = SharedServer(sessionInUse: { nil }, isEnding: { false }, renew: { _, _ in })
        await h.model.connect()
        h.server.edit { $0.meStatus = 500 }
        await h.model.signIn()
        #expect(h.model.phase != .ready)
        #expect(try h.sessions.load(for: server) == nil)
        h.server.edit { $0.meStatus = 200 }
        await h.model.connect()
        #expect(h.model.phase == .ready, "Try Again reads with the session the browser made")
        #expect(try h.sessions.load(for: server)?.cookie == FakeServer.sessionValue)
        #expect(h.server.requests.count { $0.url.path == "/api/native/token" } == 1, "no second browser sign-in")
    }

    @Test(
        "on iOS, with no other session of the server, a browser sign-in is kept in the Keychain at once, as it always was"
    )
    func iOSKeepsAtOnce() async throws {
        let h = ModelHarness()
        await h.model.connect()
        h.server.edit { $0.meStatus = 500 }
        await h.model.signIn()
        #expect(h.model.phase != .ready)
        #expect(try h.sessions.load(for: server)?.cookie == FakeServer.sessionValue)
    }

    @Test("on the Mac, a pending sign-in found at launch beside a kept session is ended: one session per server")
    func stalePendingEndedAtLaunch() async throws {
        let h = ModelHarness()
        h.model.sharedServer = SharedServer(sessionInUse: { nil }, isEnding: { false }, renew: { _, _ in })
        try h.rememberedSession()
        try h.pendingSessions.save(
            StoredSession(cookie: "left-pending", expiresAt: nil, origin: "http://localhost:4390"), for: server)
        await h.model.connect()
        await h.settle()
        #expect(h.model.phase == .ready)
        #expect(try h.sessions.load(for: server)?.cookie == FakeServer.sessionValue)
        #expect(try h.pendingSessions.load(for: server) == nil)
        #expect(h.server.snapshot.revoked.contains("left-pending"))
    }

    @Test("one sign-out that does not happen releases only its own hold on the sends: another sign-out's stays")
    func holdsAreCountedPerSignOut() async {
        let h = ModelHarness()
        await h.signedIn()
        let first = UUID()
        let second = UUID()
        h.model.holdSends(for: first)
        h.model.holdSends(for: second)
        h.model.releaseSends(for: first)
        #expect(h.model.sendsHeld, "the second sign-out's hold was released by the first's failure")
        h.model.releaseSends(for: second)
        #expect(!h.model.sendsHeld)
        h.model.releaseSends(for: second)
        #expect(!h.model.sendsHeld, "a release told twice changes nothing")
    }

    @Test("on the Mac, a session never kept is ended on the server when the model lets it go")
    func unkeptIsEndedWhenDropped() async throws {
        let h = ModelHarness()
        h.model.sharedServer = SharedServer(sessionInUse: { nil }, isEnding: { false }, renew: { _, _ in })
        await h.model.connect()
        h.server.edit { $0.meStatus = 500 }
        await h.model.signIn()
        h.model.invalidateLocalSession()
        await h.settle()
        #expect(h.server.snapshot.revoked.contains(FakeServer.sessionValue))
    }

    @Test("a session restored at launch is of an unknown age: erasing it needs a sign-in again first")
    func restoredNeedsIt() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        await h.model.connect()
        #expect(h.model.phase == .ready)
        #expect(h.model.erasureNeedsReauthentication)
    }

    @Test("a browser sign-in is recent enough to erase for a little less than the server allows, and then not")
    func recentForAWhile() async {
        let h = ModelHarness()
        await h.signedIn()
        #expect(!h.model.erasureNeedsReauthentication)
        let allowed = TimeInterval(ContractConstants.erasureSignInMinutes * 60)
        h.elapsed.set(allowed - AppModel.erasureSignInMargin - 1)
        #expect(!h.model.erasureNeedsReauthentication)
        h.elapsed.set(allowed - AppModel.erasureSignInMargin)
        #expect(h.model.erasureNeedsReauthentication)
        h.server.edit { $0.nextSession = Self.fresh }
        #expect(await h.model.reauthenticate() == .done)
        #expect(!h.model.erasureNeedsReauthentication, "signing in again starts the time again")
    }
}
