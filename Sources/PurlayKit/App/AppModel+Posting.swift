import Foundation
import PurlayContract

extension AppModel {
    // MARK: Words from outside a box

    /// Sends words to a conversation the person is not looking at: a reply typed into a notice, a forwarded message, a shortcut.
    /// Unlike a box's send it takes no files and leaves the conversation's own box and draft as they are: what was being written
    /// there is not what is sent from here. Nothing is sent with nothing in it, or that the server would refuse for its length.
    @discardableResult
    public func post(_ text: String, to channel: Uuid, parent: Uuid? = nil) -> Bool {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty, let engine, canPost(to: channel, parent: parent) else { return false }
        guard words.count <= ContractConstants.messageContentMax else {
            say(.sendTooLong)
            return false
        }
        engine.send(Outgoing(channelID: channel, content: words, parentID: parent, attachments: []))
        return true
    }

    /// Whether words from outside a box can go to a place, as the place's own box could send them: chat is on, no sign-out or
    /// erasure holds sends, the person is in the conversation (one they have not joined is only known from Browse), and a
    /// channel's feed is one they may start a conversation in (an announcement channel's is its owners' and admins', D-243).
    public func canPost(to channel: Uuid, parent: Uuid?) -> Bool {
        guard chatAvailable, !holdsSends, chat.channels[channel]?.state != nil else { return false }
        return parent != nil || canPostRoot(in: channel)
    }

    // MARK: Typing

    /// The person is writing in a channel's box (D-114): others see them typing. Only from a channel's own box (what is typed in a
    /// reply box never arrives in the channel's feed), only for words (an emptied box says nothing), and only while the window is in
    /// front of them. The engine rations it to the server's own pace, so calling it on every keystroke costs a comparison.
    public func noteTyping(_ text: String, in channel: Uuid, parent: Uuid?) {
        guard parent == nil, isActive, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        engine?.announceTyping(channel: channel)
    }
}
