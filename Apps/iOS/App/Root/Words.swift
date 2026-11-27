import Foundation

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
    static let workspace = LocalizedStringResource("Workspace")
    static let chat = LocalizedStringResource("Chat")
    static let openChatInBrowser = LocalizedStringResource("Open Chat in Browser")
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
        workspace, chat, openChatInBrowser, noWorkspaceModules, noWorkspaces, twoFactorRequired, setUpTwoFactor,
    ]

    /// Where the sign-in goes on: the person's browser, on the server's host.
    static func continuesInBrowser(_ host: String) -> LocalizedStringResource {
        LocalizedStringResource("You'll continue in your browser on \(host).")
    }
}
