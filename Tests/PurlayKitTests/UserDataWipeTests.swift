import Foundation
import PurlayTestSupport
import Testing

@testable import PurlayKit

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
        let drafts = RecordingWiper()
        let cache = RecordingWiper()
        let h = ModelHarness(wipers: [drafts, cache])
        await h.signedIn()
        _ = await h.model.signOut(scope)
        #expect(h.model.phase == .signedOut)
        #expect(drafts.wipes == 1 && cache.wipes == 1)
        #expect(h.model.notices.isEmpty, "\(h.model.notices.map(\.kind))")
    }

    @Test("a wiper that fails does not stop the others or the sign-out, and the person is told")
    func failureIsTold() async {
        let failing = RecordingWiper(fails: true)
        let after = RecordingWiper()
        let h = ModelHarness(wipers: [failing, after])
        await h.signedIn()
        #expect(await h.model.signOut(.thisDevice) == .done)
        #expect(h.model.phase == .signedOut)
        #expect(failing.wipes == 1 && after.wipes == 1)
        #expect(h.model.notices.map(\.kind) == [.dataNotWiped])
    }

    @Test("a sign-out the server could not be told of still wipes")
    func offlineWipes() async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.online = false }
        #expect(await h.model.signOut(.thisDevice) == .serverNotTold)
        #expect(wiper.wipes == 1)
    }

    @Test("a session the server ended keeps what the person made for their next sign-in")
    func endedByServerKeeps() async {
        let wiper = RecordingWiper()
        let h = ModelHarness(wipers: [wiper])
        await h.signedIn()
        h.server.edit { $0.sessionValid = false }
        await h.model.refreshAccount()
        await h.settle()
        #expect(h.model.phase == .signedOut)
        #expect(wiper.wipes == 0)
    }
}
