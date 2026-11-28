import FeatureChat
import Foundation
import PurlayWords

/// The sentences only this app says, as values its catalogue translates (`Localizable.xcstrings`). What both apps say about what
/// the engine reports (a phase, a server problem, a sign-in, a notice) is PurlayWords' `EngineWords`, and what both apps' screens
/// say otherwise (Cancel, a place in the workspace, a message's state) is its `SharedWords`, each translated once for both.
enum Words {
    static let tagline = LocalizedStringResource("Your team's conversations, in your pocket.")
    static let signInButton = LocalizedStringResource("Sign In")
    /// Said under Sign In when the server's host is not known.
    static let continuesInBrowserNoHost = LocalizedStringResource("You'll continue in your browser.")
    static let newAccount = LocalizedStringResource("New to Purlay? Create an account when you sign in.")
    /// Under a notice too long to show whole at a large text size; it opens the whole sentence. Not "Show More": the Mac says
    /// that, and a sentence lives in one catalogue.
    static let readMore = LocalizedStringResource("Read More")
    static let account = LocalizedStringResource("Account")
    static let signingOut = LocalizedStringResource("Signing out…")
    static let signOutThisDevice = LocalizedStringResource("Sign Out on This Device")
    static let signOutEverywhereDetail = LocalizedStringResource("This will end your Purlay sessions on all devices.")
    static let chat = LocalizedStringResource("Chat")
    static let conversations = LocalizedStringResource("Direct Messages")
    static let noChannels = LocalizedStringResource("No Joined Channels")
    static let channelUnavailable = LocalizedStringResource("Channel Unavailable")
    static let noMessages = LocalizedStringResource("No Messages Yet")
    static let loadingMessages = LocalizedStringResource("Loading messages…")
    static let messagesFailed = LocalizedStringResource("Couldn’t Load Messages")
    static let loadingEarlier = LocalizedStringResource("Loading earlier messages…")
    static let earlierFailed = LocalizedStringResource("Couldn’t load earlier messages.")
    static let newerFailed = LocalizedStringResource("Couldn’t load newer messages.")
    static let unknownSender = LocalizedStringResource("Unknown Sender")
    static let messageUnavailable = LocalizedStringResource("Message unavailable")
    static let writeMessage = LocalizedStringResource("Write a message")
    static let sendMessage = LocalizedStringResource("Send Message")
    static let messageTooLong = LocalizedStringResource("Message is too long.")
    static let channelReadOnly = LocalizedStringResource("Only workspace owners and admins can post here.")
    static let messageSendFailed = SharedWords.messageNotSent
    static let retryMessage = LocalizedStringResource("Retry Message")

    static let chatStrings = ChatStrings(
        starred: SharedWords.starred, channels: SharedWords.channels, conversations: conversations,
        noChannels: noChannels, channelUnavailable: channelUnavailable,
        noMessages: noMessages, loadingMessages: loadingMessages, messagesFailed: messagesFailed,
        loadEarlier: SharedWords.loadEarlier, loadingEarlier: loadingEarlier, earlierFailed: earlierFailed,
        newerFailed: newerFailed,
        jumpToLatest: SharedWords.jumpToLatest, tryAgain: EngineWords.tryAgain, unknownSender: unknownSender,
        messageUnavailable: messageUnavailable,
        writeMessage: writeMessage, sendMessage: sendMessage, messageTooLong: messageTooLong,
        channelReadOnly: channelReadOnly, sendingMessage: SharedWords.sending, sentMessage: SharedWords.sent,
        messageSendFailed: messageSendFailed, retryMessage: retryMessage, unread: SharedWords.unread)

    static let noWorkspaceModules = LocalizedStringResource("No Modules Available")
    static let noWorkspaces = LocalizedStringResource("No Workspaces Yet")
    static let setUpTwoStepVerification = LocalizedStringResource("Set Up Two-Step Verification")
    static func switchWorkspace(_ current: String) -> LocalizedStringResource {
        LocalizedStringResource("Switch Workspace, \(current)")
    }

    /// A workspace named by its name and, in brackets, its address: for two of the person's workspaces with one name.
    static func workspaceWithAddress(_ name: String, _ slug: String) -> LocalizedStringResource {
        LocalizedStringResource("\(name) (\(slug))")
    }

    /// Asked before a sign-out that deletes what is unsent.
    static func unsentWillBeDeleted(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(count) unsent messages will be deleted.")
    }

    static func backToWorkspace(_ name: String) -> LocalizedStringResource {
        LocalizedStringResource("Back to \(name)")
    }

    /// The fixed sentences of the screens, so a test can look at each in every language.
    static let fixed: [LocalizedStringResource] = [
        tagline, signInButton, continuesInBrowserNoHost, newAccount, readMore,
        account, signingOut, signOutThisDevice, signOutEverywhereDetail,
        chat, noWorkspaceModules, noWorkspaces, setUpTwoStepVerification,
        conversations, noChannels, channelUnavailable, noMessages, loadingMessages,
        messagesFailed, loadingEarlier, earlierFailed, newerFailed, unknownSender, messageUnavailable,
        writeMessage, sendMessage, messageTooLong, channelReadOnly, messageSendFailed, retryMessage,
    ]

    /// Where the sign-in goes on: the person's browser, on the server's host.
    static func continuesInBrowser(_ host: String) -> LocalizedStringResource {
        LocalizedStringResource("You'll continue in your browser on \(host).")
    }
}
