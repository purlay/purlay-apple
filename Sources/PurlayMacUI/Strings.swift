import Foundation
import PurlayContract
import PurlayKit
import PurlayWords

/// The Mac's own sentences, each a key its catalogue translates. What both apps say about what the engine reports (a notice, a
/// server problem, a sign-in, a file) is PurlayWords' `EngineWords`, translated once for both.
enum Words {
    static func header(_ kind: SidebarSection.Kind) -> String {
        switch kind {
        case .custom(_, let name): return name
        case .starred: return String(localized: SharedWords.starred)
        case .channels: return String(localized: SharedWords.channels)
        case .conversations: return String(localized: "Conversations")
        }
    }

    /// A channel is named with a hash; a conversation with people is named by them, with none.
    static func channelLabel(_ channel: Channel) -> String {
        switch channel.type {
        case .directMessage: return channel.title
        case .public, .private, .unknown: return "# \(channel.title)"
        }
    }

    // MARK: Scheduled messages and reminders

    /// What a scheduling failure says. The model's own description is English, so it is never shown; anything that is not a
    /// `SchedulingFailure` is said as a change that could not be confirmed.
    static func scheduling(_ error: any Error) -> String {
        switch (error as? SchedulingFailure) ?? .failed {
        case .unavailable: return String(localized: "This server does not support scheduled messages yet.")
        case .files: return String(localized: "Wait for every attachment to finish uploading before scheduling.")
        case .content: return String(localized: "Add a message or an attachment, within the message length limit.")
        case .time: return String(localized: "Choose a time at least a minute from now and within the next year.")
        case .limit: return String(localized: "Cancel a scheduled message before adding another.")
        case .sent:
            return String(
                localized: "This message has already been sent. Refresh the list to see what is still scheduled.")
        case .access: return String(localized: "This conversation or message is no longer available to you.")
        case .failed:
            return String(localized: "The change could not be confirmed. Check your connection and try again.")
        case .sessionChanged:
            return String(localized: "The account changed. Open this action again in the current account.")
        }
    }

    /// What a reminder failure says, for the same reason as `scheduling(_:)`.
    static func reminder(_ error: any Error) -> String {
        switch (error as? ReminderFailure) ?? .failed {
        case .unavailable: return String(localized: "This server does not support message reminders yet.")
        case .time: return String(localized: "Choose a time at least a minute from now and within the next year.")
        case .validation:
            return String(
                localized:
                    "Check the reminder time. You can keep up to \(ContractConstants.messageRemindersMax) pending reminders per workspace."
            )
        case .access: return String(localized: "This message is no longer available to you.")
        case .failed:
            return String(localized: "The reminder change could not be confirmed. Check your connection and try again.")
        case .sessionChanged:
            return String(localized: "The account changed. Open this action again in the current account.")
        }
    }

    /// How many files a scheduled message carries: one key with the count in it, so the catalogue can vary it by plural.
    static func attachmentCount(_ count: Int) -> String {
        String(localized: "\(count) attachments")
    }
}

/// What a system notice says: where and why, never what was said, because a notice is read over a shoulder and stays in the notification
/// centre (D-126 §2).
public enum AttentionWords {
    /// A channel's name as the app shows it, for the Dock menu.
    public static func place(_ channel: Channel) -> String { Words.channelLabel(channel) }

    public static func title(_ notice: AttentionNotice) -> String {
        switch notice.content {
        case .place(_, let label, _): label
        case .several: String(localized: "Purlay")
        }
    }

    public static func body(_ notice: AttentionNotice) -> String {
        switch notice.content {
        case .place(_, _, let reason):
            switch reason {
            case .directMessage: String(localized: "New message")
            case .everyMessage: String(localized: "New message")
            case .mention: String(localized: "Needs you: a mention or a reply")
            }
        case .several(let count): String(localized: "\(count) conversations need you")
        }
    }
}
