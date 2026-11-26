import Foundation

/// The sentences only this app says, as values its catalogue translates (`Localizable.xcstrings`). What both apps say about what
/// the engine reports (a phase, a server problem, a sign-in, a notice) is PurlayWords' `EngineWords`, translated once for both.
enum Words {
    static let tagline = LocalizedStringResource("Your team's conversations, in your pocket.")
    static let signInButton = LocalizedStringResource("Sign In")
    /// Said under Sign In when the server's host is not known.
    static let continuesInBrowserNoHost = LocalizedStringResource("You'll continue in your browser.")
    static let newAccount = LocalizedStringResource("New to Purlay? Create an account when you sign in.")
    static let signedInTitle = LocalizedStringResource("You're Signed In")
    static let signedInDetail = LocalizedStringResource("Nothing to show here yet.")

    /// The fixed sentences of the screens, so a test can look at each in every language.
    static let fixed: [LocalizedStringResource] = [
        tagline, signInButton, continuesInBrowserNoHost, newAccount, signedInTitle, signedInDetail,
    ]

    /// Where the sign-in goes on: the person's browser, on the server's host.
    static func continuesInBrowser(_ host: String) -> LocalizedStringResource {
        LocalizedStringResource("You'll continue in your browser on \(host).")
    }
}
