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
