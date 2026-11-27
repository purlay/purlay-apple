import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// Three workspaces of one server (Acme, Studio, Third), with `/api/me` sent with `held` kept at a door while it is shut.
private struct ThreeWorkspaces: HTTPTransport {
    static let third = "0199155c-6200-7b7f-8c11-0000000000cc"
    let inner: DesktopTransport
    let door: HeldDoor
    let held: String

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.url.path == "/api/me", request.headers["Cookie"] == "__Host-purlay_session=\(held)" {
            await door.pass()
        }
        let mine = request.url.path.contains(Self.third)
        var routed = request
        if mine {
            routed.url = URL(
                string: request.url.absoluteString.replacingOccurrences(
                    of: Self.third, with: DesktopTransport.otherWorkspace))!
        }
        var response = try await inner.send(routed)
        if request.url.path == "/api/me", response.status == 200 {
            var me = try JSONDecoder().decode(MeResponse.self, from: response.body)
            var membership = me.memberships[0]
            membership.workspace.id = Uuid(Self.third)!
            membership.workspace.name = "Third"
            membership.workspace.slug = "third"
            me.memberships.append(membership)
            response.body = try JSONEncoder().encode(me)
        } else if mine, let body = String(data: response.body, encoding: .utf8) {
            response.body = Data(body.replacingOccurrences(of: DesktopTransport.otherWorkspace, with: Self.third).utf8)
        }
        return response
    }
}

/// Fails the first `/api/me` after a browser sign-in, as a dropped connection does.
private final class FirstReadLost: HTTPTransport {
    let inner: FakeServer
    let failing = Mutex(true)
    init(inner: FakeServer) { self.inner = inner }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.url.path == "/api/me", inner.requests.contains(where: { $0.url.path == "/api/native/token" }),
            failing.withLock({ $0 })
        {
            throw TransportError.offline
        }
        return try await inner.send(request)
    }
}

private let fresh = "fresh-session"
private let stranger = "0199155c-6200-7b7f-8c11-0000000000e9"
private let address = try! ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)

/// QA (PR #7 fourth audit, d8bb5cb): what one person per server (ADR 0011) and keeping a sign-in only after `/api/me` still
/// leave open. Each fails until fixed.
@MainActor
@Suite("one person per server: what the fourth audit found")
struct ErasureFourthGapTests {
    @Test(
        "a browser sign-in whose first read is lost is still signed in after Try Again, as before the read decided keeping"
    )
    func signInSurvivesALostFirstRead() async {
        let h = ModelHarness()
        var environment = h.model.environment
        let network = FirstReadLost(inner: h.server)
        environment.transport = network
        let model = AppModel(environment)
        await model.connect()
        await model.signIn()
        #expect(model.phase == .problem(.unreachable), "the precondition: the first read was lost")
        // The connection is back. Try Again (RootScreen, the Mac's onboarding) connects again.
        network.failing.withLock { $0 = false }
        await model.connect()
        await h.settle()
        #expect(model.phase == .ready, "the sign-in the browser just made is gone: \(model.phase)")
        #expect(
            model.phase == .ready || h.server.snapshot.revoked.contains(FakeServer.sessionValue),
            "and its session is left alive on the server, kept nowhere")
    }

    @Test(
        "on the Mac, a workspace's sign-in joins only a session known to be the server's person, never one a browser just brought back"
    )
    func joinsOnlyAKeptSession() async throws {
        let door = HeldDoor()
        let opened = Mutex(0)
        let hook = Mutex<(@MainActor @Sendable () async -> Void)?>(nil)
        let browser = ScriptedBrowser { page in
            let count = opened.withLock { count in
                count += 1
                return count
            }
            if count == 1, let run = hook.withLock({ $0 }) { await run() }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let wiper = RecordingWiper()
        let h = ModelHarness(browser: browser, wipers: [wiper])
        try h.rememberedSession()
        var environment = h.model.environment
        environment.transport = ThreeWorkspaces(
            inner: DesktopTransport(first: h.server, second: FakeServer()), door: door, held: fresh)
        let mac = DesktopSessions(environment)
        await mac.launch()
        let acme = mac.active
        await mac.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: acme)
        let studio = mac.active
        await mac.selectWorkspace(Uuid(ThreeWorkspaces.third)!, from: acme)
        let third = mac.active
        #expect(acme.phase == .ready && studio.phase == .ready && third.phase == .ready)
        _ = await acme.signOut(.thisDevice)
        await h.settle()
        #expect(acme.phase == .signedOut && studio.phase == .signedOut && third.phase == .signedOut)
        opened.withLock { $0 = 0 }
        // Acme's browser is open (a stranger at the keyboard); meanwhile Ada signs in to Studio, and is the server's person.
        hook.withLock {
            $0 = {
                await studio.signIn()
                h.server.edit {
                    $0.nextSession = fresh
                    $0.userIDBySession[fresh] = stranger
                }
            }
        }
        door.shut()
        let acmeSigningIn = Task { await acme.signIn() }
        await door.awaitReached(1)
        #expect(studio.phase == .ready && studio.me?.user.id.value == FakeServer.userID, "Ada is signed in to Studio")
        // Acme's browser brought back the stranger, whose session is being read. Third asks to sign in now.
        let thirdSigningIn = Task { await third.signIn() }
        for _ in 0..<200 { await Task.yield() }
        door.open()
        await acmeSigningIn.value
        await thirdSigningIn.value
        await h.settle()
        #expect(acme.phase == .signedOut, "the stranger is refused")
        #expect(third.me?.user.id.value != stranger, "Third joined the stranger's session beside Ada's")
        #expect(studio.phase == .ready, "Ada was signed out by the stranger's refused session")
        #expect(try h.sessions.load(for: address)?.cookie == FakeServer.sessionValue, "the Keychain holds Ada's")
        withExtendedLifetime(mac) {}
    }
}

/// QA (PR #7 fourth audit): behaviour of d8bb5cb that holds today but that no test held (its mutation survived).
@MainActor
@Suite("one person per server: guards the fourth audit added")
struct ErasureFourthGuardTests {
    @Test(
        "on the Mac, a sign-out of another workspace that starts while the browser is open stops the sign-in again when it returns"
    )
    func signOutStartedWhileBrowserOpen() async throws {
        let door = HeldDoor()
        let hook = Mutex<(@MainActor @Sendable () async -> Void)?>(nil)
        let browser = ScriptedBrowser { page in
            if let run = hook.withLock({ $0 }) { await run() }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let h = ModelHarness(browser: browser, wipers: [RecordingWiper(onWipe: { await door.pass() })])
        try h.rememberedSession()
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        let mac = DesktopSessions(environment)
        await mac.launch()
        let first = mac.active
        await mac.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = mac.active
        h.server.edit { $0.nextSession = fresh }
        let signingOut = Mutex<Task<SessionManager.SignOutResult, Never>?>(nil)
        hook.withLock {
            $0 = {
                // Studio's sign-out starts while the browser is open; it is removing data when the browser returns.
                door.shut()
                signingOut.withLock { $0 = Task { await studio.signOut(.thisDevice) } }
                await door.awaitReached(1)
            }
        }
        #expect(await first.reauthenticate() == .notSignedIn)
        door.open()
        _ = await signingOut.withLock({ $0 })?.value
        await h.settle()
        #expect(first.phase == .signedOut && studio.phase == .signedOut)
        #expect(
            try h.sessions.load(for: address) == nil, "the person signed out, and the next launch signs them in again")
        #expect(h.server.snapshot.revoked.contains(fresh), "the session the browser made is left alive on the server")
        withExtendedLifetime(mac) {}
    }
}
