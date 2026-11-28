import Foundation

/// The sentences both apps' screens say that are not about something the engine reports: a control, a place in the workspace, a
/// message's state. Like `EngineWords`, each is translated once, in this module's catalogue, and names this module's bundle, so
/// the two apps cannot drift apart ("İptal" on the Mac, "Vazgeç" on iOS). What only one app says stays in that app.
public enum SharedWords {
    public static let cancel = LocalizedStringResource("Cancel", bundle: .module)
    public static let refresh = LocalizedStringResource("Refresh", bundle: .module)
    public static let workspace = LocalizedStringResource("Workspace", bundle: .module)
    public static let starred = LocalizedStringResource("Starred", bundle: .module)
    public static let channels = LocalizedStringResource("Channels", bundle: .module)
    public static let jumpToLatest = LocalizedStringResource("Jump to Latest", bundle: .module)
    public static let loadEarlier = LocalizedStringResource("Load Earlier Messages", bundle: .module)
    public static let sending = LocalizedStringResource("Sending…", bundle: .module)
    public static let sent = LocalizedStringResource("Sent", bundle: .module)
    /// A message that did not go: a send that failed in a feed, a shortcut that could not send.
    public static let messageNotSent = LocalizedStringResource("Couldn’t send message.", bundle: .module)
    public static let signOutEverywhere = LocalizedStringResource("Sign Out Everywhere", bundle: .module)
    /// The menu item that asks before it signs out everywhere.
    public static let signOutEverywhereMenu = LocalizedStringResource("Sign Out Everywhere…", bundle: .module)
    /// The account is held back until it turns two-step verification on. The web's name for it, in both languages.
    public static let twoStepVerificationRequired = LocalizedStringResource(
        "Two-Step Verification Required", bundle: .module)

    /// How many messages of a place are unread.
    public static func unread(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(count) unread", bundle: .module)
    }

    /// The fixed sentences, so a test can look at each in every language.
    public static let fixed: [LocalizedStringResource] = [
        cancel, refresh, workspace, starred, channels, jumpToLatest, loadEarlier, sending, sent, messageNotSent,
        signOutEverywhere, signOutEverywhereMenu, twoStepVerificationRequired,
    ]
}
