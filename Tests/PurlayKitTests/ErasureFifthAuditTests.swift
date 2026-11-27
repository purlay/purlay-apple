import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

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

private let pending = "pending-session"
private let address = try! ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)

@MainActor
private func mac(_ h: ModelHarness, transport: (any HTTPTransport)? = nil) -> DesktopSessions {
    var environment = h.model.environment
    environment.transport = transport ?? DesktopTransport(first: h.server, second: FakeServer())
    return DesktopSessions(environment)
}

/// Every message frame any of the harness's sockets sent.
@MainActor
private func messageFrames(_ h: ModelHarness) -> Int {
    h.sockets.reduce(0) { $0 + $1.sent.count { $0.contains("MESSAGE_SEND") } }
}

/// QA (PR #7 fifth audit, e861b6c): what the pending session and the sign-out's hold still leave open. Each fails until fixed.
@MainActor
@Suite("pending sessions and the sign-out's hold: what the fifth audit found")
struct ErasureFifthGapTests {
    @Test(
        "on the Mac, a browser sign-in still pending when the app is quit is not left alive on the server with nothing holding it"
    )
    func pendingSurvivesQuit() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let network = ReadLost(inner: DesktopTransport(first: h.server, second: FakeServer()), cookie: pending)
        var first: DesktopSessions? = mac(h, transport: network)
        await first?.launch()
        _ = await first?.active.signOut(.thisDevice)
        await h.settle()
        h.server.edit { $0.nextSession = pending }
        await first?.active.signIn()
        #expect(first?.active.phase == .problem(.unreachable), "the precondition: the first read was lost")
        // The person quits the app; the connection comes back before they open it again.
        first = nil
        network.failing.withLock { $0 = false }
        let relaunched = mac(h, transport: network)
        await relaunched.launch()
        await h.settle()
        #expect(
            relaunched.active.phase == .ready || h.server.snapshot.revoked.contains(pending),
            "the approved sign-in is gone and its session lives on, held by nothing: \(relaunched.active.phase)")
    }

    @Test("on the Mac, two browser sign-ins of the same person at once leave one session: signing out ends both")
    func twoBrowserSessionsOneServer() async throws {
        let hook = Mutex<(@MainActor @Sendable () async -> Void)?>(nil)
        let browser = ScriptedBrowser { page in
            if let run = hook.withLock({ value in
                defer { value = nil }
                return value
            }) {
                await run()
            }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let h = ModelHarness(browser: browser)
        try h.rememberedSession()
        let desktop = mac(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        _ = await first.signOut(.thisDevice)
        await h.settle()
        // Ada opens the browser in the first workspace and, before it returns, signs in to Studio too.
        hook.withLock {
            $0 = {
                h.server.edit { $0.nextSession = "studio-session" }
                await studio.signIn()
                h.server.edit { $0.nextSession = "first-session" }
            }
        }
        await first.signIn()
        await h.settle()
        #expect(first.phase == .ready && studio.phase == .ready)
        _ = await first.signOut(.thisDevice)
        await h.settle()
        let revoked = h.server.snapshot.revoked
        #expect(first.phase == .signedOut && studio.phase == .signedOut)
        #expect(
            revoked.contains("first-session") && revoked.contains("studio-session"),
            "a session of this Mac lives on after the person signed out: revoked \(revoked.sorted())")
        withExtendedLifetime(desktop) {}
    }

    @Test(
        "on the Mac, the sign-out's count of unsent messages includes those the other workspaces of the server will lose"
    )
    func unsentCountCoversWorkspaces() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = mac(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        #expect(studio.send("unsent in Studio"))
        #expect(studio.unsentMessageCount == 1, "the precondition: Studio has one unsent message")
        #expect(
            first.unsentMessageCount == 1,
            "signing out here removes Studio's unsent message, and the warning says \(first.unsentMessageCount)")
        _ = await first.signOut(.thisDevice)
        await h.settle()
        #expect(studio.unsentMessageCount == 0, "and it is removed")
        withExtendedLifetime(desktop) {}
    }

    @Test("on the Mac, a waiting send of another workspace whose file lands during the sign-out is not sent")
    func otherWorkspacesSendIsHeld() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = mac(h)
        await desktop.launch()
        let first = desktop.active
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: first)
        let studio = desktop.active
        let place = try #require(Uuid(channel(1)))
        await studio.open(place)
        for socket in h.sockets { socket.handlers.opened() }
        await h.settle()
        // The file lands while the server is told of the sign-out, whatever the load: held until then.
        let landing = Gate()
        h.server.edit { $0.beforeUploadResponse = { await landing.wait() } }
        let upload = Task {
            await studio.attach(
                [PickedFile(name: "slow.txt", data: Data(repeating: 7, count: 4))], channel: place, parent: nil)
        }
        _ = await eventually { studio.uploads(channel: place, parent: nil).count == 1 }
        #expect(studio.send("late"))
        #expect(studio.isWaiting(channel: place, parent: nil), "the precondition: the send waits for its file")
        let before = messageFrames(h)
        h.server.edit {
            $0.beforeLogoutResponse = {
                await landing.open()
                await upload.value
            }
        }
        _ = await first.signOut(.thisDevice)
        await h.settle()
        #expect(messageFrames(h) == before, "Studio sent a message the person had accepted would be removed")
        #expect(!h.server.requests.contains { $0.method == "POST" && $0.url.path.hasSuffix("/messages") })
        withExtendedLifetime(desktop) {}
    }
}
