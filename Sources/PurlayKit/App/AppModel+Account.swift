import Foundation
import PurlayContract

extension AppModel {
    // MARK: What the account is told (`GET /api/me`)

    /// The server holds this account back until it turns on two-step verification (D-239): nothing but that can be done, and it is
    /// done in the browser.
    public var mustEnrolTwoFactor: Bool { me?.mustEnrolTwoFactor == true }

    /// Workspaces the person owns whose deletion was asked for and can still be taken back, soonest erased first (D-242). A deleted
    /// workspace has left the person's memberships, so this is the one place it is still seen.
    public var scheduledDeletions: [WorkspaceDeletion] {
        (me?.scheduledDeletions ?? []).sorted { $0.purgeAt.date < $1.purgeAt.date }
    }

    /// The person's name is the one GitHub gives them, and is changed on GitHub, not here (D-235).
    public var nameFollowsGitHub: Bool { me?.nameFromGitHub == true }

    /// Where the web client is entered: it draws two-step enrolment for a held-back account and a bar for every scheduled
    /// deletion, whichever workspace it opens in.
    public var webFrontDoor: URL? { origin?.origin }

    /// Where two-step verification is turned on: the account's page in the browser, or the web client's front door while the app
    /// knows no workspace (a held-back account is given none).
    public var twoFactorSetupURL: URL? { webURL(.account) ?? webFrontDoor }

    /// Reads the account again, as when it may have changed in the browser. An account no longer held back is let in: what was
    /// not read while it was held back is read now. One asked for while one is under way waits for it, so an account let in
    /// opens its workspace once.
    public func refreshAccount() async {
        if let sessionOwner {
            await sessionOwner.refreshAccount()
            return
        }
        if let refreshingAccount { return await refreshingAccount.value }
        let run = Task { await refreshAccountOnce() }
        refreshingAccount = run
        defer { refreshingAccount = nil }
        await run.value
    }

    private func refreshAccountOnce() async {
        guard let api, phase == .ready else { return }
        let context = contextGeneration
        let held = mustEnrolTwoFactor
        guard let fresh = try? await api.getMe(), context == contextGeneration else { return }
        me = fresh
        if held && !fresh.mustEnrolTwoFactor && workspace == nil { await bootstrap() }
    }

    // MARK: Where the account is signed in (`/api/me/sessions`)

    /// The devices and browsers this account is signed in on, the one in use first, then the most recently used.
    public func deviceSessions() async throws -> [DeviceSession] {
        guard let api else { throw CancellationError() }
        return try await api.listMySessions().data.sorted {
            $0.current != $1.current ? $0.current : $0.lastUsedAt.date > $1.lastUsedAt.date
        }
    }

    /// Signs one other device out. This device is signed out with `signOut`, which also forgets what it keeps: the server ends
    /// the session a request comes in on when asked, which would leave this device holding a dead credential, so the session in
    /// use, as the server lists it now, is refused before anything is asked.
    public func endDeviceSession(_ id: Uuid) async throws {
        guard let api else { throw CancellationError() }
        let current = try await api.listMySessions().data.first(where: \.current)?.id
        guard id != current else { throw DeviceSessionRefusal.current }
        try await api.endMySession(sessionId: id.value)
    }
}

/// Why a device session was not ended.
public enum DeviceSessionRefusal: Error, Equatable, Sendable {
    /// It is the session this device uses: that is signing out, which `signOut` does.
    case current
}
