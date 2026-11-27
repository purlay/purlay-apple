import Foundation
import PurlayKit

extension EngineWords {
    /// What an erasure that did not happen says, for the screen that asked. `nil` for `erased` and `possiblyErased`: the model
    /// says those itself, as a notice, once the app is signed out. The switch names every result, so a new one does not compile until it has words.
    public static func erasure(_ result: EraseAccountResult) -> LocalizedStringResource? {
        switch result {
        case .erased, .possiblyErased: nil
        case .reauthenticationRequired:
            LocalizedStringResource("To delete your account, sign in again first.", bundle: .module)
        case .lastOwner(let workspaces): lastOwner(workspaces.count)
        case .confirmationMismatch:
            LocalizedStringResource(
                "That is not your username. Type it exactly as it is shown.", bundle: .module)
        case .refused:
            LocalizedStringResource(
                "This account cannot be deleted from here. Open Purlay on the web to see why.", bundle: .module)
        case .sessionEnded:
            LocalizedStringResource(
                "You were signed out before your account was deleted. Sign in and try again.", bundle: .module)
        case .failed:
            LocalizedStringResource(
                "Your account could not be deleted. Check your connection and try again.", bundle: .module)
        case .unconfirmed:
            LocalizedStringResource(
                "Purlay could not tell whether your account was deleted: the answer did not arrive. Check your connection and try again.",
                bundle: .module)
        }
    }

    /// What a sign-in again that did not happen says. `nil` for `done`, and for a sign-in the person closed: a choice.
    public static func reauthentication(_ result: ReauthenticationResult) -> LocalizedStringResource? {
        switch result {
        case .done: nil
        case .differentPerson:
            LocalizedStringResource(
                "You signed in with a different account. Sign in again with this one.", bundle: .module)
        case .failed(let error): signIn(error)
        case .notSignedIn: LocalizedStringResource("You are signed out.", bundle: .module)
        }
    }

    private static func lastOwner(_ count: Int) -> LocalizedStringResource {
        count == 0
            ? LocalizedStringResource(
                "You are the last owner of a workspace with other people in it. Make someone else an owner first.",
                bundle: .module)
            : LocalizedStringResource(
                "You are the last owner of \(count) workspaces with other people in them. Make someone else an owner first.",
                bundle: .module)
    }
}
