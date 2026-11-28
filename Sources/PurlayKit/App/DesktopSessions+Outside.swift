import Foundation
import PurlayContract

/// Why something asked of the app from outside its windows (Shortcuts, Spotlight, Siri) was not done. The app says each in its
/// own words.
public enum ShortcutRefusal: Error, Equatable, Sendable {
    /// The workspace in front is not signed in and ready.
    case notSignedIn
    /// The conversation is not one of the workspace's any more, or the id is not a conversation's.
    case conversationGone
    /// Nothing was sent: no words, or more than the server takes.
    case notSent
}

extension DesktopSessions {
    // MARK: Shortcuts, Spotlight and Siri

    /// The workspace in front, which is the one a shortcut acts on, as a menu item does.
    public func shortcutModel() throws(ShortcutRefusal) -> AppModel {
        guard active.phase == .ready else { throw .notSignedIn }
        return active
    }

    /// The conversations a shortcut can name: those of the workspace in front, in the sidebar's order.
    public func shortcutConversations() throws(ShortcutRefusal) -> [Channel] {
        try shortcutModel().sidebar.flatMap(\.channels)
    }

    /// The conversation a shortcut kept by its id, if the workspace in front still has it.
    public func shortcutConversation(_ id: String) throws(ShortcutRefusal) -> (model: AppModel, channel: Uuid) {
        let model = try shortcutModel()
        guard let channel = Uuid(id), model.chat.channels[channel] != nil else { throw .conversationGone }
        return (model, channel)
    }

    /// Sends a shortcut's words to a conversation of the workspace in front, as `AppModel.post` does: through the outbox, so
    /// they wait there while the Mac is offline.
    public func shortcutSend(_ text: String, to id: String) throws(ShortcutRefusal) {
        let (model, channel) = try shortcutConversation(id)
        guard model.post(text, to: channel) else { throw .notSent }
    }

    // MARK: A reply typed into a notice

    /// Sends what the person typed into a conversation's notice, from the workspace that showed it (`sourceID`, read as
    /// `openNotification` reads it). Returns whether it was sent. Words that could not be sent wait in the conversation's box,
    /// after anything already half written there, so neither is lost; when the workspace that showed the notice is no longer
    /// open, nothing holds them.
    @discardableResult
    public func reply(_ text: String, to channel: Uuid, sourceID: String?) -> Bool {
        let model: AppModel
        if let sourceID {
            guard let id = UUID(uuidString: sourceID), let session = sessions.first(where: { $0.id == id }) else {
                return false
            }
            model = session.model
        } else {
            model = active
        }
        if model.post(text, to: channel) { return true }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return false }
        let written = model.draft(for: channel)
        model.setDraft(written.isEmpty ? words : written + "\n" + words, for: channel)
        return false
    }
}
