import Foundation
import PurlayKit

extension EngineWords {
    /// Why a sign-in did not complete. `nil` for the person closing the page: that is a choice, and nothing is said of it.
    public static func signIn(_ error: SignInError) -> LocalizedStringResource? {
        switch error {
        case .cancelled: return nil
        case .browserFailed: return LocalizedStringResource("The browser could not be opened.", bundle: .module)
        case .callbackRejected:
            return LocalizedStringResource(
                "The sign-in did not come back the way it should. Try again.", bundle: .module)
        case .codeRejected:
            return LocalizedStringResource("That sign-in expired or was already used. Try again.", bundle: .module)
        case .rateLimited:
            return LocalizedStringResource("Too many attempts. Wait a moment and try again.", bundle: .module)
        case .refused: return LocalizedStringResource("The server did not accept this sign-in.", bundle: .module)
        case .noSessionInAnswer:
            return LocalizedStringResource("The server did not start a session. Try again.", bundle: .module)
        case .unreachable: return LocalizedStringResource("The server could not be reached.", bundle: .module)
        case .storage:
            return LocalizedStringResource("The session could not be saved to your Keychain.", bundle: .module)
        case .anotherPersonSignedIn(let server):
            return LocalizedStringResource("Sign out of \(server) first to use another account.", bundle: .module)
        }
    }
}
