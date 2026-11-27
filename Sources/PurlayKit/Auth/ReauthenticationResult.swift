import Foundation

/// What came of signing in again while signed in (`AppModel.reauthenticate()`), for the screen that asked: erasing the
/// account needs a sign-in within `ERASURE_SIGN_IN_MINUTES`.
public enum ReauthenticationResult: Equatable, Sendable {
    /// The same person signed in again: a new session is in use, the old one was ended, and nothing here changed.
    case done
    /// The browser signed in somebody else. Their session was ended at once and nothing here changed: the person signed in
    /// here is confirmed only by signing in as themselves, and nothing of theirs is removed for a slip in the browser.
    case differentPerson
    /// The sign-in did not happen, or whose it is could not be read: nothing changed. `.cancelled` when the person closed it.
    case failed(SignInError)
    /// Nobody is signed in, or a sign-out or an erasure is under way or ended the session meanwhile: nothing was asked.
    case notSignedIn
}
