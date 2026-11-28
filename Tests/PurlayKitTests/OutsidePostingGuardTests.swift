import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

@MainActor private func messageSends(_ socket: FakeSocket) -> [[String: Any]] {
    socket.sent.compactMap { text in
        guard let frame = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
            frame["op"] as? String == "MESSAGE_SEND"
        else { return nil }
        return frame["payload"] as? [String: Any]
    }
}

/// Words posted from outside a box (a notice's reply, a forward, a shortcut) go only where the person's own box could send them:
/// a conversation they are in, and a channel's feed only where they may start a conversation (D-243). Anything else is queued,
/// refused by the server, and lost where nobody is looking, while the shortcut or the notice said it was sent.
@MainActor
@Suite("words from outside a box go only where the person may post")
struct OutsidePostingGuardTests {
    /// Channel 3 is an announcement channel the person is in; channel 4 a public channel they have not joined (Browse's).
    private func signedIn() async -> ModelHarness {
        let h = ModelHarness()
        h.server.edit {
            $0.chans += [
                .init(n: 3, name: "announcements", onlyAdminsPost: true),
                .init(n: 4, name: "random", joined: false),
            ]
        }
        await h.signedIn()
        await h.settle()
        return h
    }

    @Test("nothing is posted to a public channel the person has not joined")
    func notJoined() async throws {
        let h = await signedIn()
        let random = try #require(Uuid(channel(4)))
        #expect(h.model.chat.channels[random] != nil, "the channel is known, as Browse knows it")
        #expect(h.model.chat.channels[random]?.state == nil, "and the person is not in it")
        #expect(!h.model.post("hello", to: random))
        #expect(messageSends(h.last).isEmpty)
    }

    @Test("a root is not posted to an announcement channel by a member who may only reply there")
    func announcementRoot() async throws {
        let h = await signedIn()
        let announcements = try #require(Uuid(channel(3)))
        #expect(!h.model.canPostRoot(in: announcements))
        #expect(!h.model.post("hello", to: announcements))
        #expect(messageSends(h.last).isEmpty)
        #expect(h.model.post("agreed", to: announcements, parent: idAt(1_000)), "a reply in a thread is everybody's")
    }

    @Test("a shortcut that names a channel the person has left is refused, not queued")
    func shortcutNotJoined() async throws {
        let h = ModelHarness()
        h.server.edit { $0.chans.append(.init(n: 4, name: "random", joined: false)) }
        try h.rememberedSession()
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        let desktop = DesktopSessions(environment)
        await desktop.launch()
        for socket in h.sockets { socket.handlers.opened() }
        await h.settle()

        #expect(!(try desktop.shortcutConversations().map(\.id).contains(Uuid(channel(4))!)))
        #expect(throws: ShortcutRefusal.conversationGone) { try desktop.shortcutSend("hello", to: channel(4)) }
        #expect(throws: ShortcutRefusal.conversationGone) { try desktop.shortcutConversation(channel(4)) }
        #expect(!desktop.reply("hello", to: Uuid(channel(4))!, sourceID: desktop.selectedID.uuidString))
        #expect(messageSends(h.last).isEmpty)
    }
}

/// A notice's Reply can be the thing that starts the app (macOS launches it to deliver the response), so `reply` can run before
/// the sessions have launched: no engine, and no `me`, so no drafts store. FR-132 says words that cannot be sent wait in the
/// conversation's box; here they must be either sent once the app is up or kept, never dropped.
@MainActor
@Suite("a notice's reply on a cold start")
struct ColdStartReplyTests {
    @Test("a reply that arrives before the launch is sent or kept, not lost")
    func replyBeforeLaunch() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        let desktop = DesktopSessions(environment)
        let api = try #require(Uuid(channel(1)))

        let sentAtOnce = desktop.reply("on my way", to: api, sourceID: desktop.selectedID.uuidString)
        await desktop.launch()
        for socket in h.sockets { socket.handlers.opened() }
        await h.settle()

        let sent = h.sockets.flatMap { messageSends($0) }.contains { $0["content"] as? String == "on my way" }
        let kept = desktop.active.draft(for: api).contains("on my way")
        #expect(sentAtOnce || sent || kept, "the words typed into the notice are gone")
    }
}

/// `endDeviceSession` is "one other device" (its own words, FR-224): the session in use is ended with `signOut`, which also
/// forgets what this device keeps. The server ends the caller's own session when asked (API.md, `DELETE /api/me/sessions/:id`),
/// which would leave this device holding a dead credential, so the engine must not ask.
@MainActor
@Suite("ending a device session")
struct EndDeviceSessionGuardTests {
    @Test("the session in use is not ended from the devices list, and the server is not asked")
    func currentRefused() async throws {
        let h = ModelHarness()
        let stamp = FakeServer.decoded(Timestamp.self, #""2026-10-12T12:00:00.000Z""#)
        let current = idAt(3_002)
        h.server.edit {
            $0.deviceSessions = [
                DeviceSession(
                    createdAt: stamp, current: true, expiresAt: stamp, id: current, kind: .native, lastUsedAt: stamp,
                    name: "This Mac")
            ]
        }
        await h.signedIn()
        _ = try await h.model.deviceSessions()
        await #expect(throws: (any Error).self) { try await h.model.endDeviceSession(current) }
        #expect(
            !h.server.requests.contains { $0.method == "DELETE" && $0.url.path.hasPrefix("/api/me/sessions/") },
            "the server ends the caller's own session when asked; the engine must refuse before it asks")
    }
}
