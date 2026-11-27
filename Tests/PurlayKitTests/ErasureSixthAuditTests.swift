import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// Counts `/auth/logout`, and holds every one after `limit` for good: a launch that keeps ending sessions is stopped, not run
/// for ever, and the count says it.
private final class LogoutCounter: HTTPTransport {
    let inner: any HTTPTransport
    let limit: Int
    let count = Mutex(0)
    init(inner: any HTTPTransport, limit: Int) {
        self.inner = inner
        self.limit = limit
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.url.path == "/auth/logout" {
            let seen = count.withLock { count in
                count += 1
                return count
            }
            if seen > limit { try await Task.sleep(for: .seconds(3_600)) }
        }
        return try await inner.send(request)
    }
}

/// Fails `/api/me` sent with `cookie` while `failing` is set: a first read lost after a browser sign-in.
private final class ReadLost: HTTPTransport {
    let inner: any HTTPTransport
    let cookie: String
    let failing = Mutex(true)
    init(inner: any HTTPTransport, cookie: String) {
        self.inner = inner
        self.cookie = cookie
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.url.path == "/api/me", request.headers["Cookie"] == "__Host-purlay_session=\(cookie)",
            failing.withLock({ $0 })
        {
            throw TransportError.offline
        }
        return try await inner.send(request)
    }
}

private let address = try! ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)

/// QA (PR #7 sixth audit, e129fc2): what the pending sign-in kept in the Keychain still leaves open. Each fails until fixed.
@MainActor
@Suite("the pending sign-in in the Keychain: what the sixth audit found")
struct ErasureSixthGapTests {
    @Test(
        "on the Mac, a pending sign-in kept for another origin than the server's now is ended once at launch, not for ever"
    )
    func pendingOfAnotherOriginEndsOnce() async throws {
        let h = ModelHarness()
        let counter = LogoutCounter(inner: h.server, limit: 3)
        var environment = h.model.environment
        environment.transport = counter
        let model = AppModel(environment)
        model.sharedServer = SharedServer(sessionInUse: { nil }, isEnding: { false }, renew: { _, _ in })
        // The app was quit with a sign-in pending; the server's address (its `appUrl`) has changed since.
        try h.pendingSessions.save(
            StoredSession(cookie: "left-pending", expiresAt: nil, origin: "https://old.example.test"), for: address)
        let launching = Task { await model.connect() }
        _ = await eventually { counter.count.withLock { $0 } > 3 || model.phase == .signedOut }
        let logouts = counter.count.withLock { $0 }
        #expect(
            logouts <= 1, "the launch ends the same pending session again and again: \(logouts) logouts and counting")
        #expect(model.phase == .signedOut, "the app never gets past its launch: \(model.phase)")
        #expect(try h.pendingSessions.load(for: address) == nil, "the pending entry is left, so every launch loops")
        launching.cancel()
    }

    @Test("on the Mac, a second workspace's sign-in does not take the first's pending sign-in out of the Keychain")
    func twoPendingOneEntry() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let network = ReadLost(inner: DesktopTransport(first: h.server, second: FakeServer()), cookie: "first-pending")
        var environment = h.model.environment
        environment.transport = network
        var desktop: DesktopSessions? = DesktopSessions(environment)
        await desktop?.launch()
        let first = try #require(desktop?.active)
        await desktop?.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = try #require(desktop?.active)
        _ = await first.signOut(.thisDevice)
        await h.settle()
        h.server.edit { $0.nextSession = "first-pending" }
        await first.signIn()
        #expect(first.phase == .problem(.unreachable), "the precondition: the first workspace's sign-in is pending")
        h.server.edit { $0.nextSession = "studio-session" }
        await studio.signIn()
        await h.settle()
        #expect(studio.phase == .ready)
        // The person quits with the first workspace still on its problem screen.
        desktop = nil
        network.failing.withLock { $0 = false }
        let relaunched = DesktopSessions(environment)
        await relaunched.launch()
        await h.settle()
        #expect(
            h.server.snapshot.revoked.contains("first-pending"),
            "the first workspace's approved sign-in lives on the server, held by nothing")
        withExtendedLifetime(relaunched) {}
    }
}

/// QA (PR #7 sixth audit): behaviour of e129fc2 that holds today but that no test held (each one's mutation survived).
@MainActor
@Suite("the pending sign-in in the Keychain: guards the sixth audit added")
struct ErasureSixthGuardTests {
    @Test("on the Mac, a sign-out that does not happen lets every other workspace of the server send again")
    func failedSignOutReleasesOtherWorkspaces() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        let desktop = DesktopSessions(environment)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        let place = try #require(Uuid(channel(1)))
        await studio.open(place)
        h.server.edit { $0.uploadDelays["slow.txt"] = 60 }
        let upload = Task {
            await studio.attach(
                [PickedFile(name: "slow.txt", data: Data(repeating: 7, count: 4))], channel: place, parent: nil)
        }
        _ = await eventually { studio.uploads(channel: place, parent: nil).count == 1 }
        #expect(studio.send("late"))
        h.server.edit {
            $0.beforeLogoutResponse = { await upload.value }
            $0.logoutStatus = 500
        }
        #expect(await first.signOut(.everywhere) == .notDone("the server could not be reached"))
        await h.settle()
        #expect(first.phase == .ready && studio.phase == .ready)
        #expect(
            !studio.isWaiting(channel: place, parent: nil),
            "Studio's send is held for good after a sign-out that failed")
        withExtendedLifetime(desktop) {}
    }

    @Test("on the Mac, a pending sign-in let go is taken out of the Keychain as well as ended")
    func droppedPendingLeavesNoEntry() async throws {
        let h = ModelHarness()
        var environment = h.model.environment
        environment.transport = ReadLost(inner: h.server, cookie: "pending-session")
        let model = AppModel(environment)
        model.sharedServer = SharedServer(sessionInUse: { nil }, isEnding: { false }, renew: { _, _ in })
        await model.connect()
        h.server.edit { $0.nextSession = "pending-session" }
        await model.signIn()
        #expect(model.phase == .problem(.unreachable))
        #expect(
            try h.pendingSessions.load(for: address)?.cookie == "pending-session", "the precondition: kept as pending")
        model.invalidateLocalSession()
        _ = await eventually { h.server.snapshot.revoked.contains("pending-session") }
        #expect(
            try h.pendingSessions.load(for: address) == nil, "the next launch reads again with a session already ended")
    }
}
