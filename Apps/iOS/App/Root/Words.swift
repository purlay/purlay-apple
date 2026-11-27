import FeatureChat
import Foundation
import PurlayWords

/// The sentences only this app says, as values its catalogue translates (`Localizable.xcstrings`). What both apps say about what
/// the engine reports (a phase, a server problem, a sign-in, a notice) is PurlayWords' `EngineWords`, translated once for both.
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
    static let cancel = LocalizedStringResource("Cancel")
    static let signingOut = LocalizedStringResource("Signing out…")
    static let signOutThisDevice = LocalizedStringResource("Sign Out on This Device")
    static let signOutEverywhere = LocalizedStringResource("Sign Out Everywhere")
    static let signOutEverywhereMenu = LocalizedStringResource("Sign Out Everywhere…")
    static let signOutEverywhereDetail = LocalizedStringResource("This will end your Purlay sessions on all devices.")
    static let workspace = LocalizedStringResource("Workspace")
    static let chat = LocalizedStringResource("Chat")
    static let starred = LocalizedStringResource("Starred")
    static let channels = LocalizedStringResource("Channels")
    static let conversations = LocalizedStringResource("Direct Messages")
    static let noChannels = LocalizedStringResource("No Joined Channels")
    static let channelUnavailable = LocalizedStringResource("Channel Unavailable")
    static let noMessages = LocalizedStringResource("No Messages Yet")
    static let loadingMessages = LocalizedStringResource("Loading messages…")
    static let messagesFailed = LocalizedStringResource("Couldn’t Load Messages")
    static let loadEarlier = LocalizedStringResource("Load Earlier Messages")
    static let loadingEarlier = LocalizedStringResource("Loading earlier messages…")
    static let earlierFailed = LocalizedStringResource("Couldn’t load earlier messages.")
    static let jumpToLatest = LocalizedStringResource("Jump to Latest")
    static let unknownSender = LocalizedStringResource("Unknown Sender")
    static let messageUnavailable = LocalizedStringResource("Message unavailable")
    static let writeMessage = LocalizedStringResource("Write a message")
    static let sendMessage = LocalizedStringResource("Send Message")
    static let messageTooLong = LocalizedStringResource("Message is too long.")
    static let channelReadOnly = LocalizedStringResource("Only workspace owners and admins can post here.")
    static let sendingMessage = LocalizedStringResource("Sending…")
    static let sentMessage = LocalizedStringResource("Sent")
    static let messageSendFailed = LocalizedStringResource("Couldn’t send message.")
    static let retryMessage = LocalizedStringResource("Retry Message")
    static func unread(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(count) unread")
    }

    static let chatStrings = ChatStrings(
        starred: starred, channels: channels, conversations: conversations,
        noChannels: noChannels, channelUnavailable: channelUnavailable,
        noMessages: noMessages, loadingMessages: loadingMessages, messagesFailed: messagesFailed,
        loadEarlier: loadEarlier, loadingEarlier: loadingEarlier, earlierFailed: earlierFailed,
        jumpToLatest: jumpToLatest, tryAgain: EngineWords.tryAgain, unknownSender: unknownSender,
        messageUnavailable: messageUnavailable,
        writeMessage: writeMessage, sendMessage: sendMessage, messageTooLong: messageTooLong,
        channelReadOnly: channelReadOnly, sendingMessage: sendingMessage, sentMessage: sentMessage,
        messageSendFailed: messageSendFailed, retryMessage: retryMessage, unread: unread)

    static let noWorkspaceModules = LocalizedStringResource("No Modules Available")
    static let noWorkspaces = LocalizedStringResource("No Workspaces Yet")
    static let twoFactorRequired = LocalizedStringResource("Two-Factor Authentication Required")
    static let setUpTwoFactor = LocalizedStringResource("Set Up Two-Factor Authentication")
    static func switchWorkspace(_ current: String) -> LocalizedStringResource {
        LocalizedStringResource("Switch Workspace, \(current)")
    }

    static func backToWorkspace(_ name: String) -> LocalizedStringResource {
        LocalizedStringResource("Back to \(name)")
    }

    /// The fixed sentences of the screens, so a test can look at each in every language.
    static let fixed: [LocalizedStringResource] = [
        tagline, signInButton, continuesInBrowserNoHost, newAccount, readMore,
        account, cancel, signingOut, signOutThisDevice, signOutEverywhere, signOutEverywhereMenu,
        signOutEverywhereDetail,
        workspace, chat, noWorkspaceModules, noWorkspaces, twoFactorRequired, setUpTwoFactor,
        starred, channels, conversations, noChannels, channelUnavailable, noMessages, loadingMessages,
        messagesFailed, loadEarlier, loadingEarlier, earlierFailed, jumpToLatest, unknownSender, messageUnavailable,
        writeMessage, sendMessage, messageTooLong, channelReadOnly, sendingMessage, sentMessage, messageSendFailed,
        retryMessage,
    ]

    /// Where the sign-in goes on: the person's browser, on the server's host.
    static func continuesInBrowser(_ host: String) -> LocalizedStringResource {
        LocalizedStringResource("You'll continue in your browser on \(host).")
    }
}
