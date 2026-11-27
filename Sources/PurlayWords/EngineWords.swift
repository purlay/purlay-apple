import Foundation
import PurlayContract
import PurlayKit

/// The sentences both apps say about what the engine reports: a phase under way, a server that cannot be used, a sign-in that
/// did not complete, a notice, a file that did not upload, and the two things a person can do about one. They are translated
/// once, in this module's catalogue (`Resources/Localizable.xcstrings`), and each is a `LocalizedStringResource` that names this
/// module's bundle, so either app finds the translation here and never in a copy of its own. What only one app says stays in
/// that app.
///
/// The model hands over what happened; this says it. The server's own `message` and a platform error's description are English
/// written for a log, and never reach a person.
public enum EngineWords {
    public static let connecting = LocalizedStringResource("Connecting…", bundle: .module)
    public static let waitingForBrowser = LocalizedStringResource("Waiting for the Browser…", bundle: .module)
    public static let loadingWorkspace = LocalizedStringResource("Loading your workspace…", bundle: .module)
    public static let tryAgain = LocalizedStringResource("Try Again", bundle: .module)
    public static let dismiss = LocalizedStringResource("Dismiss", bundle: .module)

    /// The fixed sentences, so a test can look at each in every language.
    public static let fixed: [LocalizedStringResource] = [
        connecting, waitingForBrowser, loadingWorkspace, tryAgain, dismiss,
    ]
}
