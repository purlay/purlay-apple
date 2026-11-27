import Foundation
import PurlayContract

/// The routes the generated client leaves out because the pinned contract's table does not carry them yet
/// (`PurlayContract/PendingEndpoints.swift`, TD-026).
extension PurlayAPI {
    /// `POST /api/me/erase`: erases the caller's account; `confirm` is their username, typed. Never retried by the client: a
    /// second request after an erasure that committed is refused as signed out.
    public func eraseMyAccount(body: EraseAccountRequest) async throws {
        try await client.sendEmpty(Endpoints.eraseMyAccount, body: body)
    }
}
