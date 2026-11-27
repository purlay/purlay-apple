import Foundation
import PurlayContract

/// What came of asking the server to erase the person's account (`POST /api/me/erase`, D-139 §5): what the screen acts on.
/// Only `erased` changes anything here; every other answer leaves the person signed in, except `sessionEnded`.
public enum EraseAccountResult: Equatable, Sendable {
    /// The account is gone: this app is signed out and what it kept of the person is removed.
    case erased
    /// The last sign-in is older than `ERASURE_SIGN_IN_MINUTES`: sign in again through the browser, then ask again.
    case reauthenticationRequired
    /// The person is the last owner of these workspaces, each with other people in it: hand them over first. Empty when the
    /// server did not say which.
    case lastOwner(workspaceIDs: [Uuid])
    /// What was typed is not the person's username.
    case confirmationMismatch
    /// The server will not erase this account from here: a session given by a company's sign-in, the server's last
    /// administrator, or an account held back until two-step verification is on.
    case refused
    /// The session ended before the account was erased: the app is signed out, as when the server ends a session.
    case sessionEnded
    /// The server could not be reached or did not answer as it should: nothing was erased, and asking again is safe.
    case failed

    /// What a failed request means. A `401` is `sessionEnded`, since the client has already ended the session it refused.
    init(_ error: any Error) {
        guard let error = error as? APIError else {
            self = .failed
            return
        }
        switch (error.status, error.code) {
        case (401, _): self = .sessionEnded
        case (_, .reauthenticationRequired): self = .reauthenticationRequired
        case (_, .validationFailed): self = .confirmationMismatch
        case (_, .lastOwner): self = .lastOwner(workspaceIDs: Self.workspaceIDs(in: error.details))
        case (403, _): self = .refused
        default: self = .failed
        }
    }

    /// `details.workspaceIds` of a `LAST_OWNER` answer, as the contract types it; none when it is missing or not that shape.
    private static func workspaceIDs(in details: JSONValue?) -> [Uuid] {
        guard let details, let data = try? JSONEncoder().encode(details),
            let read = try? JSONDecoder().decode(AppErrorBody.LastOwner.Details.self, from: data)
        else { return [] }
        return read.workspaceIds
    }
}
