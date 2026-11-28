import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

@MainActor private func sends(_ socket: FakeSocket) -> [[String: Any]] {
    socket.sent.compactMap { text in
        guard let frame = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
            frame["op"] as? String == "MESSAGE_SEND"
        else { return nil }
        return frame["payload"] as? [String: Any]
    }
}

/// What is asked of the app from outside its windows: a shortcut (Shortcuts, Spotlight, Siri) and a reply typed into a notice.
@MainActor
@Suite("requests from outside the windows")
struct OutsideRequestsTests {
    private func desktop(_ h: ModelHarness) -> DesktopSessions {
        var environment = h.model.environment
        environment.transport = DesktopTransport(first: h.server, second: FakeServer())
        return DesktopSessions(environment)
    }

    private func launched() async throws -> (ModelHarness, DesktopSessions) {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        for socket in h.sockets { socket.handlers.opened() }
        await h.settle()
        return (h, desktop)
    }

    // MARK: Shortcuts

    @Test("a shortcut is refused while the workspace in front is not signed in")
    func shortcutSignedOut() async throws {
        let h = ModelHarness()
        let desktop = desktop(h)
        await desktop.launch()
        #expect(desktop.active.phase != .ready)
        await #expect(throws: ShortcutRefusal.notSignedIn) { try await desktop.shortcutModel() }
        await #expect(throws: ShortcutRefusal.notSignedIn) { try await desktop.shortcutConversations() }
        await #expect(throws: ShortcutRefusal.notSignedIn) { try await desktop.shortcutSend("hello", to: channel(1)) }
        #expect(h.sockets.allSatisfy { sends($0).isEmpty })
    }

    @Test("a shortcut that starts the app finds the person signed in, and is not told to sign in")
    func shortcutColdStart() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        #expect(desktop.active.phase == .launching)
        let model = try await desktop.shortcutModel()
        #expect(model.phase == .ready)
        #expect(model === desktop.active)
    }

    @Test("a shortcut that comes while the window's own launch is under way waits for it to end")
    func shortcutDuringLaunch() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        let window = Task { await desktop.launch() }
        await Task.yield()
        let conversations = try await desktop.shortcutConversations()
        #expect(desktop.active.phase == .ready)
        #expect(!conversations.isEmpty)
        await window.value
        #expect(h.server.requests.filter { $0.url.path == "/api/me" }.count == 1, "the workspace is launched once")
    }

    @Test("a shortcut names the conversations of the workspace in front, in the sidebar's order")
    func shortcutConversations() async throws {
        let (_, desktop) = try await launched()
        let named = try await desktop.shortcutConversations().map(\.id)
        #expect(!named.isEmpty)
        #expect(named == desktop.active.sidebar.flatMap(\.channels).map(\.id))
    }

    @Test("a conversation a shortcut kept is found by its id, and one that is gone or not an id is refused")
    func shortcutConversation() async throws {
        let (_, desktop) = try await launched()
        let found = try await desktop.shortcutConversation(channel(1))
        #expect(found.model === desktop.active)
        #expect(found.channel == Uuid(channel(1)))
        await #expect(throws: ShortcutRefusal.conversationGone) { try await desktop.shortcutConversation(channel(9)) }
        await #expect(throws: ShortcutRefusal.conversationGone) { try await desktop.shortcutConversation("general") }
    }

    @Test("a shortcut's words are sent to the conversation it names; no words, or too many, are refused")
    func shortcutSend() async throws {
        let (h, desktop) = try await launched()
        try await desktop.shortcutSend("  on my way ", to: channel(2))
        let sent = sends(h.last)
        #expect(sent.count == 1)
        #expect(sent.first?["channelId"] as? String == channel(2))
        #expect(sent.first?["content"] as? String == "on my way")
        await #expect(throws: ShortcutRefusal.notSent) { try await desktop.shortcutSend(" \n", to: channel(2)) }
        await #expect(throws: ShortcutRefusal.notSent) {
            try await desktop.shortcutSend(
                String(repeating: "a", count: ContractConstants.messageContentMax + 1), to: channel(2))
        }
        await #expect(throws: ShortcutRefusal.conversationGone) {
            try await desktop.shortcutSend("hello", to: channel(9))
        }
        #expect(sends(h.last).count == 1)
    }

    // MARK: A reply typed into a notice

    @Test(
        "a reply goes to the workspace that showed the notice, though another is in front and shares the channel's id")
    func replyRoutesToItsWorkspace() async throws {
        let h = ModelHarness()
        try h.rememberedSession()
        let desktop = desktop(h)
        await desktop.launch()
        let firstID = desktop.selectedID
        await desktop.selectWorkspace(Uuid(DesktopTransport.otherWorkspace)!, from: desktop.active)
        for socket in h.sockets { socket.handlers.opened() }
        await h.settle()
        #expect(desktop.selectedID != firstID)
        #expect(h.sockets.count == 2)

        #expect(await desktop.reply("thanks", to: Uuid(channel(1))!, sourceID: firstID.uuidString))
        #expect(sends(h.sockets[0]).map { $0["content"] as? String } == ["thanks"])
        #expect(
            sends(h.sockets[1]).isEmpty, "the workspace in front shares the id, and is not where the notice came from")
        #expect(desktop.selectedID != firstID, "a reply leaves the window where it is")
    }

    @Test("a reply that cannot be sent waits in the conversation's box, after what was half written there")
    func replyKeptAsDraft() async throws {
        let (h, desktop) = try await launched()
        let source = desktop.selectedID.uuidString
        let tooLong = String(repeating: "a", count: ContractConstants.messageContentMax + 1)
        let other = Uuid(channel(2))!
        #expect(!(await desktop.reply(tooLong, to: other, sourceID: source)))
        #expect(desktop.active.draft(for: other) == tooLong)

        desktop.active.setDraft("half a thought", for: other)
        #expect(!(await desktop.reply("see you", to: Uuid(channel(9))!, sourceID: source)))
        #expect(desktop.active.draft(for: Uuid(channel(9))!) == "see you")
        #expect(!(await desktop.reply(tooLong, to: other, sourceID: source)))
        #expect(desktop.active.draft(for: other) == "half a thought\n" + tooLong)
        #expect(sends(h.last).isEmpty)
    }

    @Test("a reply with no words, or from a workspace no longer open, sends and keeps nothing")
    func replyRefused() async throws {
        let (h, desktop) = try await launched()
        let other = Uuid(channel(2))!
        #expect(!(await desktop.reply("  ", to: other, sourceID: desktop.selectedID.uuidString)))
        #expect(!(await desktop.reply("hello", to: other, sourceID: UUID().uuidString)))
        #expect(!(await desktop.reply("hello", to: other, sourceID: "not an id")))
        #expect(desktop.active.draft(for: other).isEmpty)
        #expect(sends(h.last).isEmpty)
    }

    @Test("a notice that names no workspace is answered from the one in front")
    func replyWithoutSource() async throws {
        let (h, desktop) = try await launched()
        #expect(await desktop.reply("ok", to: Uuid(channel(1))!, sourceID: nil))
        #expect(sends(h.last).map { $0["channelId"] as? String } == [channel(1)])
    }
}
