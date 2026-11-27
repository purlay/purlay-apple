import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// QA (PR #7 third audit, 1174b05): a door a test holds shut until it says so, and reports when somebody reaches it.
private final class Door: Sendable {
    private let state = Mutex<(open: Bool, reached: Bool, waiting: [CheckedContinuation<Void, Never>])>(
        (true, false, []))

    func shut() { state.withLock { $0.open = false } }
    var reached: Bool { state.withLock { $0.reached } }

    func pass() async {
        await withCheckedContinuation { continuation in
            let through = state.withLock { door -> Bool in
                door.reached = true
                if door.open { return true }
                door.waiting.append(continuation)
                return false
            }
            if through { continuation.resume() }
        }
    }

    func open() {
        let waiting = state.withLock { door -> [CheckedContinuation<Void, Never>] in
            door.open = true
            defer { door.waiting = [] }
            return door.waiting
        }
        for continuation in waiting { continuation.resume() }
    }

    /// Waits, a bounded while, for somebody to reach the door.
    func awaitReached() async {
        for _ in 0..<100_000 where !reached { await Task.yield() }
    }
}

/// The two-workspace transport, with `/api/me` sent with `cookie` held at a door while it is shut.
private struct HeldTransport: HTTPTransport {
    let inner: DesktopTransport
    let door: Door
    let cookie: String

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.url.path == "/api/me", request.headers["Cookie"] == "__Host-purlay_session=\(cookie)" {
            await door.pass()
        }
        return try await inner.send(request)
    }
}

private let fresh = "fresh-session"
private let adasFresh = "adas-fresh-session"
private let stranger = "0199155c-6200-7b7f-8c11-0000000000e9"
private let address = try! ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)

@MainActor
private func desktop(_ h: ModelHarness, holding door: Door? = nil) -> DesktopSessions {
    var environment = h.model.environment
    let inner = DesktopTransport(first: h.server, second: FakeServer())
    environment.transport =
        door.map { HeldTransport(inner: inner, door: $0, cookie: FakeServer.sessionValue) } ?? inner
    return DesktopSessions(environment)
}

/// Ada signed in to the first workspace of the server, and a second workspace (Studio) asked to sign in as somebody else.
/// One person per server (ADR 0011): Studio joins Ada's session, and nobody else is signed in.
@MainActor
private func twoPeople(_ h: ModelHarness) async throws -> (DesktopSessions, ada: AppModel, other: AppModel) {
    try h.rememberedSession()
    let desktop = desktop(h)
    await desktop.launch()
    let first = desktop.active
    await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
    let studio = desktop.active
    _ = await studio.signOut(.thisDevice)
    await h.settle()
    await first.signIn()
    h.server.edit {
        $0.nextSession = fresh
        $0.userIDBySession[fresh] = stranger
    }
    await studio.signIn()
    await h.settle()
    return (desktop, first, studio)
}

/// QA (PR #7 third audit, 1174b05): what the fixes for I-A, I-B, I-C and M-A still leave open. Each fails until fixed.
@MainActor
@Suite("erasure and signing in again: what the third audit found")
struct ErasureThirdGapTests {
    @Test(
        "on the Mac, a workspace still reading who the person is when they sign in again moves to the new session too")
    func loadingWorkspaceMovesToo() async throws {
        let door = Door()
        let target = Mutex<(DesktopSessions, AppModel)?>(nil)
        let browser = ScriptedBrowser { page in
            // While the browser is open the person opens another workspace; its first read is still out when they return.
            if let (desktop, first) = target.withLock({ $0 }) {
                door.shut()
                Task { @MainActor in
                    await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
                }
                await door.awaitReached()
            }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let h = ModelHarness(browser: browser)
        try h.rememberedSession()
        let desktop = desktop(h, holding: door)
        await desktop.launch()
        let first = desktop.active
        #expect(first.phase == .ready)
        target.withLock { $0 = (desktop, first) }
        h.server.edit { $0.nextSession = fresh }
        #expect(await first.reauthenticate() == .done)
        let studio = try #require(desktop.sessions.last?.model)
        // The precondition: its first read, on the old session, is still held. (It may already have read again on the new
        // session, which is the fix: what the old read finds must not undo that.)
        #expect(studio !== first && door.reached, "the precondition: still reading")
        door.open()
        await h.settle()
        #expect(first.phase == .ready, "the workspace that signed in again was signed out by one still loading")
        #expect(studio.phase == .ready)
        #expect(
            !(first.notices + studio.notices).map(\.kind).contains(.sessionEndedByServer),
            "\(first.notices.map(\.kind)) \(studio.notices.map(\.kind))")
    }

    @Test(
        "on the Mac, after an unconfirmed erasure, an end heard first by another workspace of the server is still the erasure's"
    )
    func unconfirmedHeardByAnotherWorkspace() async throws {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        h.server.edit { $0.eraseThrows = .timedOut }
        #expect(await first.eraseAccount(confirmation: "ada") == .unconfirmed)
        // The erasure went through: every session of the account is gone, and Studio's read is the first to hear it.
        h.server.edit {
            $0.eraseThrows = nil
            $0.sessionValid = false
        }
        await studio.refreshAccount()
        await h.settle()
        #expect(first.phase == .signedOut && studio.phase == .signedOut)
        let said = (first.notices + studio.notices).map(\.kind)
        #expect(!said.contains(.sessionEndedByServer), "told to sign in again, which makes a new account: \(said)")
        #expect(said.contains(.accountPossiblyErased), "\(said)")
        #expect(wiper.wipes > 0, "the probably erased person's drafts and outbox stay on the Mac")
    }

    @Test("an unconfirmed mark left by a launch that found the session expired is not read back for a later sign-in")
    func staleMarkAfterExpiredLaunch() async throws {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.eraseThrows = .timedOut }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .unconfirmed)
        // The app is quit. The erasure never happened, and the session's time passes before the app is opened again.
        h.server.edit { $0.eraseThrows = nil }
        try h.sessions.save(
            StoredSession(
                cookie: FakeServer.sessionValue, expiresAt: Date(timeIntervalSince1970: 1),
                origin: "http://localhost:4390"),
            for: address)
        let second = AppModel(h.model.environment)
        await second.connect()
        #expect(second.phase == .signedOut)
        await second.signIn()
        await h.settle()
        #expect(second.phase == .ready, "Ada signs in again: her account is there")
        // Opened again later; the server then ends this session with no reason given (a read refused).
        let third = AppModel(h.model.environment)
        await third.connect()
        await h.settle()
        #expect(third.phase == .ready)
        h.server.edit { $0.sessionValid = false }
        await third.refreshAccount()
        await h.settle()
        #expect(
            !third.notices.map(\.kind).contains(.accountPossiblyErased),
            "a live account told it was probably deleted, from a mark of a launch long ago: \(third.notices.map(\.kind))"
        )
        #expect(wiper.wipes == 0, "an existing account's drafts and outbox were removed")
    }

    @Test(
        "on the Mac, signing in again while another workspace's sign-out is removing data does not put a live session back"
    )
    func signInAgainDuringAnotherWorkspacesSignOut() async throws {
        let door = Door()
        let wiper = RecordingWiper(onWipe: { await door.pass() })
        let h = ModelHarness(wipers: [wiper])
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        door.shut()
        h.server.edit { $0.nextSession = fresh }
        let signingOut = Task { await studio.signOut(.thisDevice) }
        // Studio's sign-out told the server and removed the credential; its data is being removed.
        await door.awaitReached()
        _ = await first.reauthenticate()
        door.open()
        _ = await signingOut.value
        await h.settle()
        #expect(first.phase == .signedOut && studio.phase == .signedOut)
        #expect(
            try h.sessions.load(for: address) == nil, "the person signed out, and the next launch signs them in again")
        // Refused before the browser opens (another workspace is signing out), or, if it opened, its session is ended.
        #expect(
            !h.server.requests.contains { $0.url.path == "/api/native/token" }
                || h.server.snapshot.revoked.contains(fresh),
            "the session the browser made is left alive on the server")
    }

    @Test(
        "on the Mac, a second workspace's sign-in where Ada is signed in joins her session: Ada keeps it, and her data, across a relaunch"
    )
    func twoPeopleKeepTheirSignIns() async throws {
        let h = ModelHarness()
        let tokens = { h.server.requests.count { $0.url.path == "/api/native/token" } }
        try h.rememberedSession()
        let mac = desktop(h)
        await mac.launch()
        let first = mac.active
        await mac.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = mac.active
        _ = await studio.signOut(.thisDevice)
        await h.settle()
        await first.signIn()
        let afterAda = tokens()
        h.server.edit {
            $0.nextSession = fresh
            $0.userIDBySession[fresh] = stranger
        }
        await studio.signIn()
        await h.settle()
        #expect(tokens() == afterAda, "joined without the browser")
        #expect(first.me?.user.id.value == FakeServer.userID && studio.me?.user.id.value == FakeServer.userID)
        let place = try #require(Uuid(channel(1)))
        first.setDraft("ada's draft", for: place)
        let relaunched = desktop(h)
        await relaunched.launch()
        await h.settle()
        let people = relaunched.sessions.map { $0.model.me?.user.id.value }
        #expect(people.allSatisfy { $0 == FakeServer.userID }, "\(people)")
        let adasDraft = Drafts.key(user: try #require(Uuid(FakeServer.userID)), channel: place, parent: nil)
        #expect(h.preferences.string(for: adasDraft) == "ada's draft", "Ada's draft was removed at launch")
        withExtendedLifetime(mac) {}
    }

    @Test(
        "on the Mac, a browser that brings back somebody else where Ada is signed in is refused: their session ends, nothing is kept or removed, and Ada stays"
    )
    func anotherPersonsSignOutKeepsAda() async throws {
        let target = Mutex<AppModel?>(nil)
        let browser = ScriptedBrowser { page in
            // While Studio's browser is open, Ada signs in to the first workspace; Studio's browser then brings back a stranger.
            if let first = target.withLock({ $0 }) {
                target.withLock { $0 = nil }
                await first.signIn()
            }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let wiper = RecordingWiper()
        let h = ModelHarness(browser: browser, wipers: [wiper])
        try h.rememberedSession()
        let mac = desktop(h)
        await mac.launch()
        let first = mac.active
        await mac.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = mac.active
        _ = await studio.signOut(.thisDevice)
        await h.settle()
        let wipesBefore = wiper.wipes
        target.withLock { $0 = first }
        h.server.edit { $0.nextSession = nil }
        let strangerOnReturn = Task { @MainActor in
            // The token Studio's code buys is the stranger's: set once Ada's own sign-in has bought hers.
            while first.phase != .ready { await Task.yield() }
            h.server.edit {
                $0.nextSession = fresh
                $0.userIDBySession[fresh] = stranger
            }
        }
        await studio.signIn()
        await strangerOnReturn.value
        await h.settle()
        #expect(first.phase == .ready && first.me?.user.id.value == FakeServer.userID)
        #expect(studio.phase == .signedOut)
        #expect(
            studio.notices.map(\.kind) == [.signInFailed(.anotherPersonSignedIn(server: "localhost"))],
            "\(studio.notices.map(\.kind))")
        #expect(h.server.snapshot.revoked.contains(fresh), "the stranger's session is left alive")
        #expect(try h.sessions.load(for: address)?.cookie == FakeServer.sessionValue, "the Keychain holds Ada's")
        #expect(wiper.wipes == wipesBefore, "nothing of anybody's was removed")
        let relaunched = desktop(h)
        await relaunched.launch()
        await h.settle()
        #expect(relaunched.sessions.allSatisfy { $0.model.me?.user.id.value == FakeServer.userID })
        withExtendedLifetime(mac) {}
    }
}

/// QA (PR #7 third audit): behaviour of 1174b05 that holds today but that no test held (each one's mutation survived).
@MainActor
@Suite("erasure and signing in again: guards the third audit added")
struct ErasureThirdGuardTests {
    @Test(
        "on the Mac, the old session's ending said on another workspace's old socket is not heard after signing in again"
    )
    func siblingOldSocketIsLeft() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        let studiosSocket = h.last
        h.server.edit { $0.nextSession = fresh }
        #expect(await first.reauthenticate() == .done)
        // The server tells the old session's sockets it was signed out (`/auth/logout` of the old session).
        studiosSocket.handlers.message(#"{"event":"SESSION_ENDED","ts":1,"data":{"reason":"signed-out"}}"#)
        await h.settle()
        #expect(first.phase == .ready && studio.phase == .ready)
        #expect(first.notices.isEmpty && studio.notices.isEmpty)
    }

    @Test("on the Mac, a workspace that joined Ada's session moves with it when she signs in again elsewhere")
    func strangersWorkspaceIsNotRenewed() async throws {
        let h = ModelHarness()
        let (sessions, ada, other) = try await twoPeople(h)
        #expect(other.me?.user.id.value == FakeServer.userID, "joined Ada's session")
        h.server.edit { $0.nextSession = adasFresh }
        #expect(await ada.reauthenticate() == .done)
        await other.refreshAccount()
        await h.settle()
        #expect(other.phase == .ready && ada.phase == .ready)
        let read = try #require(h.server.requests.last { $0.url.path == "/api/me" })
        #expect(read.headers["Cookie"] == "__Host-purlay_session=\(adasFresh)")
        withExtendedLifetime(sessions) {}
    }

    @Test(
        "on the Mac, erasing the account in one workspace removes what every other workspace of the server kept of them"
    )
    func erasureWipesOtherWorkspaces() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        let place = try #require(Uuid(channel(1)))
        studio.setDraft("kept in Studio", for: place)
        let key = Drafts.key(user: try #require(Uuid(FakeServer.userID)), channel: place, parent: nil)
        #expect(studio.environment.preferences.string(for: key) == "kept in Studio")
        #expect(await first.eraseAccount(confirmation: "ada") == .erased)
        await h.settle()
        #expect(studio.phase == .signedOut)
        #expect(studio.environment.preferences.string(for: key) == nil, "the erased person's draft is left in Studio")
        withExtendedLifetime(desktop) {}
    }

    @Test(
        "an unconfirmed erasure is forgotten with its session: a later sign-in's ending is the server's, not an erasure"
    )
    func markGoesWithTheSession() async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.eraseThrows = .timedOut }
        #expect(await h.model.eraseAccount(confirmation: "ada") == .unconfirmed)
        _ = await h.model.signOut(.thisDevice)
        #expect(h.preferences.string(for: AppModel.unconfirmedErasureKey(for: address)) == nil)
        h.server.edit { $0.eraseThrows = nil }
        await h.model.signIn()
        await h.settle()
        #expect(h.model.phase == .ready)
        h.server.edit { $0.sessionValid = false }
        await h.model.refreshAccount()
        await h.settle()
        #expect(h.model.notices.map(\.kind).last == .sessionEndedByServer)
        #expect(wiper.wipes == 1, "only the sign-out's")
    }
}
