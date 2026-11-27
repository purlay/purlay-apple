import Foundation
import Synchronization
import Testing

@testable import PurlayKit

/// A store of the person's that counts its wipes, and can refuse them as a store that cannot be removed does.
final class CountingWiper: UserDataWiper {
    struct Refused: Error {}
    private let count = Mutex(0)
    private let fails: Bool

    init(fails: Bool = false) { self.fails = fails }

    var wipes: Int { count.withLock { $0 } }

    func wipe() async throws {
        count.withLock { $0 += 1 }
        if fails { throw Refused() }
    }
}

/// P-6: what the app keeps of a person on this device goes when they sign out, through the wipers its environment names.
@MainActor
@Suite("signing out wipes what the environment keeps of the person")
struct UserDataWipeTests {
    @Test(
        "signing out, here or everywhere, runs every wiper of the environment once",
        arguments: [
            SignOutScope.thisDevice, .everywhere,
        ])
    func signOutWipes(scope: SignOutScope) async {
        let drafts = CountingWiper()
        let cache = CountingWiper()
        let h = ModelHarness(wipers: [drafts, cache])
        await h.signedIn()
        _ = await h.model.signOut(scope)
        #expect(h.model.phase == .signedOut)
        #expect(drafts.wipes == 1 && cache.wipes == 1)
        #expect(h.model.notices.isEmpty, "\(h.model.notices.map(\.kind))")
    }

    @Test("a wiper that fails does not stop the others or the sign-out, and the person is told")
    func failureIsTold() async {
        let failing = CountingWiper(fails: true)
        let after = CountingWiper()
        let h = ModelHarness(wipers: [failing, after])
        await h.signedIn()
        #expect(await h.model.signOut(.thisDevice) == .done)
        #expect(h.model.phase == .signedOut)
        #expect(failing.wipes == 1 && after.wipes == 1)
        #expect(h.model.notices.map(\.kind) == [.dataNotWiped])
    }

    @Test("a sign-out the server could not be told of still wipes")
    func offlineWipes() async {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.online = false }
        #expect(await h.model.signOut(.thisDevice) == .serverNotTold)
        #expect(wiper.wipes == 1)
    }

    @Test("a session the server ended keeps what the person made for their next sign-in")
    func endedByServerKeeps() async {
        let wiper = CountingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.sessionValid = false }
        await h.model.refreshAccount()
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(wiper.wipes == 0)
    }
}
