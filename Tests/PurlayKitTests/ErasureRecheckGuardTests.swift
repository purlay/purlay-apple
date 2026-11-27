import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// QA (PR #7 re-audit): behaviour that holds today but that no test held (each one's mutation survived the suite).
@MainActor
@Suite("erasure and signing in again: guards the re-audit added")
struct ErasureRecheckGuardTests {
    private static let fresh = "fresh-session"
    private let server = try! ServerAddress.parse("localhost:4390", allowsLocalHTTP: true)

    @Test("a sign-out while the browser is open wins: the new session is ended and nothing is adopted")
    func signOutWhileBrowserOpen() async throws {
        let target = Mutex<AppModel?>(nil)
        let opened = Mutex(0)
        let browser = ScriptedBrowser { page in
            let count = opened.withLock { count in
                count += 1
                return count
            }
            if count > 1, let model = target.withLock({ $0 }) { _ = await model.signOut(.thisDevice) }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let h = ModelHarness(browser: browser)
        await h.signedIn()
        target.withLock { $0 = h.model }
        h.server.edit { $0.nextSession = Self.fresh }
        #expect(await h.model.reauthenticate() == .notSignedIn)
        #expect(h.model.phase == .signedOut)
        #expect(try h.sessions.load(for: server) == nil, "a sign-out's credential removal is not undone")
        let logouts = h.server.requests.filter { $0.url.path == "/auth/logout" }.map { $0.headers["Cookie"] }
        #expect(logouts.contains("__Host-purlay_session=\(Self.fresh)"), "the session the browser made is ended")
    }

    @Test("two sign-ins again asked together open one browser and share its answer")
    func twoAtOnce() async {
        let opened = Mutex(0)
        let browser = ScriptedBrowser { page in
            opened.withLock { $0 += 1 }
            for _ in 0..<20 { await Task.yield() }
            return try await ScriptedBrowser.approving.answer(page)
        }
        let h = ModelHarness(browser: browser)
        await h.signedIn()
        h.server.edit { $0.nextSession = Self.fresh }
        let model = h.model!
        async let first = model.reauthenticate()
        async let second = model.reauthenticate()
        let answers = await [first, second]
        #expect(answers == [.done, .done])
        #expect(opened.withLock { $0 } == 2, "the first sign-in, then one browser for both")
    }

    @Test("on the Mac, a workspace's own drafts go when the person signs out of another workspace of the server")
    func scopedDraftsGo() async throws {
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
        // Written and kept (not sent: sending consumes the draft, which would prove nothing).
        first.setDraft("workspace one", for: place)
        studio.setDraft("workspace two", for: place)
        let key = Drafts.key(user: try #require(Uuid(FakeServer.userID)), channel: place, parent: nil)
        #expect(studio.environment.preferences.string(for: key) == "workspace two")
        _ = await first.signOut(.thisDevice)
        await h.settle()
        #expect(first.environment.preferences.string(for: key) == nil)
        #expect(studio.environment.preferences.string(for: key) == nil, "the other workspace's scoped draft is left")
    }
}
