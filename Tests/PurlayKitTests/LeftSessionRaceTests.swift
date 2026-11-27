import Foundation
import PurlayContract
import PurlayTestSupport
import Synchronization
import Testing

@testable import PurlayKit

/// The Mac's workspaces of one server end together. What a workspace kept of the person who left is removed after it ends;
/// a sign-in in that workspace meanwhile must not be ended, or its data removed, by that late removal.
@MainActor
@Suite("a workspace signed in again while what it kept of the person who left is removed")
struct LeftSessionRaceTests {
    /// Holds the second wipe (the other workspace's removal of what it kept) until the test lets it go.
    private final class SecondWipe: Sendable {
        private let count = Mutex(0)
        private let held = Mutex<CheckedContinuation<Void, Never>?>(nil)
        private let reached = Mutex(false)

        func wipe() async {
            guard
                count.withLock({
                    $0 += 1
                    return $0
                }) == 2
            else { return }
            await withCheckedContinuation { continuation in
                held.withLock { $0 = continuation }
                reached.withLock { $0 = true }
            }
        }

        var isHeld: Bool { reached.withLock { $0 } }
        func release() { held.withLock { $0 }?.resume() }
    }

    @Test("a sign-in made while the previous person's data is being removed stays signed in, and keeps what it writes")
    func signInDuringLateRemoval() async throws {
        let second = SecondWipe()
        let h = ModelHarness(wipers: [RecordingWiper(onWipe: { await second.wipe() })])
        try h.rememberedSession()
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        let mac = DesktopSessions(environment)
        await mac.launch()
        let acme = mac.active
        await mac.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: acme)
        let studio = mac.active
        _ = await acme.signOut(.thisDevice)
        // Studio's removal of what it kept is under way, and held.
        _ = await eventually { second.isHeld }
        #expect(second.isHeld, "the precondition: Studio's removal is under way")
        let tokens = { h.server.requests.count { $0.url.path == "/api/native/token" } }
        let before = tokens()
        let signingIn = Task { await studio.signIn() }
        // Given every chance to go on, the sign-in waits for the removal: it does not start a session it would end.
        _ = await eventually { tokens() > before }
        #expect(tokens() == before, "signed in while the previous session's data was still being removed")
        second.release()
        await signingIn.value
        await h.settle()
        #expect(studio.phase == .ready, "the sign-in was ended by the removal that was meant for the session before it")
        let place = try #require(Uuid(channel(1)))
        studio.setDraft("written after signing in", for: place)
        await h.settle()
        #expect(studio.draft(for: place) == "written after signing in")
        withExtendedLifetime(mac) {}
    }
}
