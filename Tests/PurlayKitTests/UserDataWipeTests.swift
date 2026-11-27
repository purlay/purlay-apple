import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
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
    // MARK: What the engine keeps of the person (P-6)

    private var outbox: (ModelHarness) -> URL { { $0.directory.appendingPathComponent("outbox", isDirectory: true) } }

    @Test("signing out removes every draft in this environment's preferences, another person's too, and nothing else")
    func draftsGo() async throws {
        let h = ModelHarness()
        await h.signedIn()
        let place = try #require(Uuid(channel(1)))
        h.model.setDraft("half written", for: place)
        let key = Drafts.key(user: try #require(Uuid(FakeServer.userID)), channel: place, parent: nil)
        let leftOver = "purlay.draft.0199155c-6200-7b7f-8c11-0000000000e2.\(place.value)"
        h.preferences.set("not theirs either", for: leftOver)
        #expect(h.preferences.string(for: key) == "half written")
        _ = await h.model.signOut(.thisDevice)
        #expect(h.preferences.string(for: key) == nil)
        #expect(h.preferences.string(for: leftOver) == nil)
        #expect(h.preferences.string(for: "workspace") == "acme", "what is not the person's stays")
    }

    @Test("signing out removes the outbox, unsent messages and set-aside files included")
    func outboxGoes() async throws {
        let h = ModelHarness()
        await h.signedIn()
        #expect(h.model.send("not yet delivered"))
        let file = outbox(h).appendingPathComponent("\(FakeServer.userID).json")
        #expect(FileManager.default.fileExists(atPath: file.path))
        try Data("[]".utf8).write(to: outbox(h).appendingPathComponent("\(FakeServer.userID).corrupt-1"))
        _ = await h.model.signOut(.thisDevice)
        #expect(!FileManager.default.fileExists(atPath: outbox(h).path))
    }

    @Test("a send that changes the outbox while the person's data is being removed does not write it back")
    func outboxNotWrittenBack() async throws {
        let target = Mutex<AppModel?>(nil)
        // Runs after the engine's own wipers: the outbox is gone, and the engine is still running.
        let late = RecordingWiper(onWipe: {
            let model = target.withLock { $0 }
            await MainActor.run { _ = model?.send("written after the wipe") }
        })
        let h = ModelHarness(wipers: [late])
        target.withLock { $0 = h.model }
        await h.signedIn()
        #expect(h.model.send("not yet delivered"))
        _ = await h.model.signOut(.thisDevice)
        #expect(late.wipes == 1)
        #expect(!FileManager.default.fileExists(atPath: outbox(h).path))
    }

    @Test("the Quick Look copies under this environment's caches go on sign-out")
    func previewsGo() async throws {
        let h = ModelHarness()
        await h.signedIn()
        let folder = h.model.previewsDirectory.appendingPathComponent("an-attachment", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: folder.appendingPathComponent("plan.pdf"))
        _ = await h.model.signOut(.thisDevice)
        #expect(!FileManager.default.fileExists(atPath: h.model.previewsDirectory.path))
    }

    @Test("an erased account's drafts and outbox go as a sign-out's do")
    func erasureWipes() async throws {
        let h = ModelHarness()
        await h.signedIn()
        let place = try #require(Uuid(channel(1)))
        h.model.setDraft("half written", for: place)
        #expect(h.model.send("not yet delivered"))
        #expect(await h.model.eraseAccount(confirmation: "ada") == .erased)
        #expect(!FileManager.default.fileExists(atPath: outbox(h).path))
        let key = Drafts.key(user: try #require(Uuid(FakeServer.userID)), channel: place, parent: nil)
        #expect(h.preferences.string(for: key) == nil)
    }

    @Test("the messages not yet sent are counted, so the sign-out screen can say what will go")
    func unsentCounted() async {
        let h = ModelHarness()
        await h.signedIn()
        #expect(h.model.unsentMessageCount == 0)
        #expect(h.model.send("one"))
        #expect(h.model.send("two"))
        #expect(h.model.unsentMessageCount == 2)
    }
}

@Suite("removing preferences by their prefix")
struct PreferencePrefixTests {
    @Test("the defaults remove every key that begins with the prefix, and only those")
    func defaults() throws {
        let suite = "dev.purlay.kit-tests.prefix-\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let preferences = UserDefaultsPreferences(suite: suite)
        preferences.set("a", for: "purlay.draft.u.c")
        preferences.set("b", for: "purlay.draft.u.c.t")
        preferences.set("acme", for: "workspace")
        preferences.set("kept", for: "x.purlay.draft.u.c")
        preferences.removeValues(withPrefix: "purlay.draft.")
        #expect(preferences.string(for: "purlay.draft.u.c") == nil)
        #expect(preferences.string(for: "purlay.draft.u.c.t") == nil)
        #expect(preferences.string(for: "workspace") == "acme")
        #expect(preferences.string(for: "x.purlay.draft.u.c") == "kept")
    }
}
