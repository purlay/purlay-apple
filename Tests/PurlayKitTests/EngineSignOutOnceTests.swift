import Foundation
import Testing

@testable import PurlayKit

/// The Mac's Sign Out (sidebar, menu, command) and Check Again call the model directly, and Check Again also runs each time the
/// app becomes active, with nothing between a second call and the server: the iOS app's `RootActions.once` guards only the iOS
/// screens, which do not offer either yet. The model is what both apps share, so "once while one is under way" belongs to it.
@MainActor
@Suite("the engine signs out and refreshes once while one is under way")
struct EngineSignOutOnceTests {
    @Test("two quick Sign Outs tell the server once, and nothing is said of the second")
    func signOutOnce() async {
        let h = ModelHarness()
        await h.signedIn()
        async let first = h.model.signOut(.thisDevice)
        async let second = h.model.signOut(.thisDevice)
        _ = await (first, second)
        let logouts = h.server.requests.filter { $0.url.path == "/auth/logout" }
        #expect(logouts.count == 1, "the server is told \(logouts.count) times")
        #expect(h.model.phase == .signedOut)
        #expect(h.model.notices.isEmpty, "\(h.model.notices.map(\.kind))")
    }

    @Test("two quick Check Agains read the account once")
    func refreshOnce() async {
        let h = ModelHarness()
        await h.signedIn()
        let before = h.server.requests.filter { $0.url.path == "/api/me" }.count
        async let first: Void = h.model.refreshAccount()
        async let second: Void = h.model.refreshAccount()
        _ = await (first, second)
        let reads = h.server.requests.filter { $0.url.path == "/api/me" }.count - before
        #expect(reads == 1, "the account is read \(reads) times")
    }

    // The Mac runs Check Again on the button and on didBecomeActive: back from the browser, a click lands beside the activation.
    @Test("two Check Agains on an account just let in open its workspace once, with one socket")
    func letInOnce() async {
        let h = ModelHarness()
        h.server.edit { $0.mustEnrolTwoFactor = true }
        await h.signedIn()
        #expect(h.model.workspace == nil)
        h.server.edit { $0.mustEnrolTwoFactor = false }
        let before = h.server.requests.filter { $0.url.path.hasSuffix("/channels") }.count
        let socketsBefore = h.sockets.count
        async let first: Void = h.model.refreshAccount()
        async let second: Void = h.model.refreshAccount()
        _ = await (first, second)
        await h.settle()
        let loads = h.server.requests.filter { $0.url.path.hasSuffix("/channels") }.count - before
        #expect(loads == 1, "the workspace is loaded \(loads) times")
        #expect(h.model.workspace?.slug == "acme")
        let open = h.sockets.dropFirst(socketsBefore).filter { !$0.closedByClient }
        #expect(open.count <= 1, "\(open.count) sockets left open for one workspace")
    }
}
