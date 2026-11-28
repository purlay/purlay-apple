import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

@MainActor private func frames(_ op: String, _ socket: FakeSocket) -> [[String: Any]] {
    socket.sent.compactMap { text in
        guard let frame = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
            frame["op"] as? String == op
        else { return nil }
        return frame
    }
}

private func payload(_ frame: [String: Any]?) -> [String: Any] { frame?["payload"] as? [String: Any] ?? [:] }

/// Words sent from outside a box: a reply typed into a notice, a forwarded message, a shortcut.
@MainActor
@Suite("sending to a conversation that is not open")
struct PostingTests {
    @Test("words go to the named conversation, not the open one, and its box and draft are left as they were")
    func postsElsewhere() async throws {
        let h = ModelHarness()
        await h.signedIn()
        await h.settle()
        let other = try #require(Uuid(channel(2)))
        h.model.setDraft("half a thought", for: other)
        #expect(h.model.selectedChannel == Uuid(channel(1)))
        #expect(h.model.post("  on my way  ", to: other))
        let sent = frames("MESSAGE_SEND", h.last)
        #expect(sent.count == 1)
        #expect(payload(sent.first)["channelId"] as? String == channel(2))
        #expect(payload(sent.first)["content"] as? String == "on my way")
        #expect(h.model.draft(for: other) == "half a thought")
    }

    @Test("a reply goes into its thread")
    func postsReply() async throws {
        let h = ModelHarness()
        await h.signedIn()
        await h.settle()
        let root = idAt(1_000)
        #expect(h.model.post("agreed", to: try #require(Uuid(channel(2))), parent: root))
        #expect(payload(frames("MESSAGE_SEND", h.last).first)["parentId"] as? String == root.value)
    }

    @Test("nothing is sent with no words, to a conversation the person is not in, or past the server's length")
    func refuses() async throws {
        let h = ModelHarness()
        await h.signedIn()
        await h.settle()
        let other = try #require(Uuid(channel(2)))
        #expect(!h.model.post(" \n ", to: other))
        #expect(!h.model.post("hello", to: try #require(Uuid(channel(9)))))
        #expect(!h.model.post(String(repeating: "a", count: ContractConstants.messageContentMax + 1), to: other))
        #expect(frames("MESSAGE_SEND", h.last).isEmpty)
    }
}

/// Typing (D-114): others see the person typing in a channel's box, at the server's own pace.
@MainActor
@Suite("telling others the person is typing")
struct TypingAnnouncementTests {
    private func signedIn() async -> ModelHarness {
        let h = ModelHarness()
        await h.signedIn()
        await h.settle()
        return h
    }

    @Test("words in a channel's box say so, for that channel")
    func says() async throws {
        let h = await signedIn()
        h.model.noteTyping("h", in: try #require(Uuid(channel(1))), parent: nil)
        let said = frames("TYPING", h.last)
        #expect(said.count == 1)
        #expect(payload(said.first)["channelId"] as? String == channel(1))
    }

    @Test("rationed per channel, however fast the person types; a send makes the next keystroke news again")
    func rationed() async throws {
        let h = await signedIn()
        let one = try #require(Uuid(channel(1)))
        for letter in ["h", "he", "hel"] { h.model.noteTyping(letter, in: one, parent: nil) }
        #expect(frames("TYPING", h.last).count == 1)
        h.model.noteTyping("x", in: try #require(Uuid(channel(2))), parent: nil)
        #expect(frames("TYPING", h.last).count == 2, "another channel is its own ration")
        #expect(h.model.send("hello"))
        h.model.noteTyping("n", in: one, parent: nil)
        #expect(frames("TYPING", h.last).count == 3)
    }

    @Test("an emptied box, a reply box and a window that is not in front say nothing")
    func silent() async throws {
        let h = await signedIn()
        let one = try #require(Uuid(channel(1)))
        h.model.noteTyping("  ", in: one, parent: nil)
        h.model.noteTyping("reply", in: one, parent: idAt(1_000))
        h.model.setActive(false)
        h.model.noteTyping("away", in: one, parent: nil)
        #expect(frames("TYPING", h.last).isEmpty)
    }
}

@MainActor
@Suite("channel members, edit history and devices")
struct AccountAndChannelReadsTests {
    @Test("a person is added to the channel asked for; a refusal throws and adds nobody")
    func addsMember() async throws {
        let h = ModelHarness()
        await h.signedIn()
        let ada = try #require(Uuid(FakeServer.userID))
        try await h.model.addMember(ada, to: try #require(Uuid(channel(2))))
        #expect(h.server.snapshot.memberAdds.map(\.channel) == [channel(2)])
        #expect(h.server.snapshot.memberAdds.map(\.user) == [FakeServer.userID])
        h.server.edit { $0.mutationStatus = 403 }
        await #expect(throws: APIError.self) {
            try await h.model.addMember(ada, to: try #require(Uuid(channel(1))))
        }
        #expect(h.server.snapshot.memberAdds.count == 1)
    }

    @Test("an edited message's earlier versions are read newest first, a page at a time")
    func versions() async throws {
        let h = ModelHarness()
        let message = idAt(1_000)
        let stamp = FakeServer.decoded(Timestamp.self, #""2026-10-09T12:00:00.000Z""#)
        let kept = (1...3).map { MessageVersion(content: "draft \($0)", id: idAt(2_000 + $0), replacedAt: stamp) }
        h.server.edit { $0.versions[message.value] = kept }
        await h.signedIn()
        let first = try await h.model.versions(of: message)
        #expect(first.data.map(\.content) == ["draft 1", "draft 2", "draft 3"])
        #expect(first.nextCursor == nil)
        let after = try await h.model.versions(of: message, before: kept[0].id)
        #expect(after.data.map(\.content) == ["draft 2", "draft 3"])
    }

    @Test("devices list this one first, then the most recently used; another one can be signed out")
    func devices() async throws {
        let h = ModelHarness()
        func stamp(_ day: Int) -> Timestamp {
            FakeServer.decoded(Timestamp.self, #""2026-10-\#(day)T12:00:00.000Z""#)
        }
        func session(_ n: Int, current: Bool, used: Int) -> DeviceSession {
            DeviceSession(
                createdAt: stamp(10), current: current, expiresAt: stamp(28), id: idAt(3_000 + n),
                kind: n.isMultiple(of: 2) ? .browser : .native, lastUsedAt: stamp(used), name: "Device \(n)")
        }
        h.server.edit {
            $0.deviceSessions = [
                session(1, current: false, used: 11), session(2, current: true, used: 12),
                session(3, current: false, used: 20),
            ]
        }
        await h.signedIn()
        #expect(try await h.model.deviceSessions().map(\.name) == ["Device 2", "Device 3", "Device 1"])
        try await h.model.endDeviceSession(idAt(3_003))
        #expect(h.server.snapshot.endedSessions == [idAt(3_003).value])
        #expect(try await h.model.deviceSessions().map(\.name) == ["Device 2", "Device 1"])
    }
}

@MainActor
@Suite("the engine's typing ration")
struct TypingRationTests {
    @Test("said again once half of the announcement's life has passed, so it never runs out while the person types")
    func halfLife() throws {
        let h = EngineHarness()
        let socket = h.openOne()
        let one = try #require(Uuid(channel(1)))
        h.engine.announceTyping(channel: one)
        h.clockBox.milliseconds += Double(ContractConstants.typingTtlMs / 2 - 1)
        h.engine.announceTyping(channel: one)
        #expect(frames("TYPING", socket).count == 1)
        h.clockBox.milliseconds += 1
        h.engine.announceTyping(channel: one)
        #expect(frames("TYPING", socket).count == 2)
    }
}
