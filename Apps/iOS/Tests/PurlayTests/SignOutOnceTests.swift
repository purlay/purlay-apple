import PurlayKit
import Testing

@testable import Purlay

@MainActor
@Suite("signing out and refreshing, once each")
struct SignOutOnceTests {
    // RootActions promises that "a second tap that arrives before the first has changed the phase finds the phase changed". Sign
    // out keeps the phase `.ready` until the server has answered, so a second tap passes the guard and signs out again.
    @Test("two quick taps on sign out tell the server once, and nothing is said of the second")
    func signOutOnce() async throws {
        let harness = Harness([
            Harness.clientInfo(), Harness.meWithoutWorkspace(),
            ScriptedTransport.json(204, ""), ScriptedTransport.json(204, ""),
        ])
        try harness.rememberSession()
        await harness.model.connect()
        #expect(harness.model.phase == .ready)

        async let first = RootActions.signOut(harness.model, everywhere: false)
        async let second = RootActions.signOut(harness.model, everywhere: false)
        _ = await (first, second)

        let logouts = await harness.transport.requests.filter { $0.url.path.hasSuffix("/auth/logout") }
        #expect(logouts.count == 1, "the server is told once, not \(logouts.count) times")
        #expect(harness.model.phase == .signedOut)
        #expect(harness.model.notices.isEmpty)
    }

    // Refreshing the account keeps the phase `.ready` too, so the phase cannot stop a second tap either.
    @Test("two quick taps on refresh ask the server for the account once")
    func refreshOnce() async throws {
        let harness = Harness([
            Harness.clientInfo(), Harness.meWithoutWorkspace(), Harness.meWithoutWorkspace(),
            Harness.meWithoutWorkspace(),
        ])
        try harness.rememberSession()
        await harness.model.connect()
        #expect(harness.model.phase == .ready)
        let asked = await harness.transport.requests.count

        async let first: Void = RootActions.refreshAccount(harness.model)
        async let second: Void = RootActions.refreshAccount(harness.model)
        _ = await (first, second)

        #expect(await harness.transport.requests.count == asked + 1, "one account request, not two")
    }
}
