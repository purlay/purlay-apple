import PurlayKit

/// What stands on the screen for each phase of the app's model. A pure value, so each phase's screen is decided in one place and
/// tested without drawing anything: a person never stands in front of a state that is not one of these.
enum RootScreen: Equatable {
    /// Something is under way and the person waits: the words say what.
    case busy(Busy)
    case problem(ServerProblem)
    case signIn
    /// Signed in, but the account must enrol a second step before it is given a workspace.
    case twoFactorRequired
    /// Signed in with nothing to open: the account belongs to no workspace.
    case noWorkspace
    /// Signed in and the first screen has loaded. The module screens come with the shell; until then this says so.
    case ready

    enum Busy: Equatable {
        case connecting, signingIn, loading
    }

    /// Two-step comes before no workspace, because a held-back account is given none.
    init(phase: AppModel.Phase, mustEnrolTwoFactor: Bool, hasWorkspace: Bool) {
        switch phase {
        case .launching, .checking: self = .busy(.connecting)
        case .signingIn: self = .busy(.signingIn)
        case .loading: self = .busy(.loading)
        case .problem(let problem): self = .problem(problem)
        case .signedOut: self = .signIn
        case .ready:
            if mustEnrolTwoFactor {
                self = .twoFactorRequired
            } else if !hasWorkspace {
                self = .noWorkspace
            } else {
                self = .ready
            }
        }
    }

    /// Whether the brand mark stands on this screen: while something is under way, and on Welcome. Elsewhere it fades out.
    var showsMark: Bool {
        switch self {
        case .busy, .signIn: true
        case .problem, .twoFactorRequired, .noWorkspace, .ready: false
        }
    }

    @MainActor
    init(_ model: AppModel) {
        self.init(
            phase: model.phase, mustEnrolTwoFactor: model.mustEnrolTwoFactor, hasWorkspace: model.workspace != nil)
    }
}

/// What a tap on a screen does. A second tap that arrives before the first has changed the phase finds the phase changed, and does
/// nothing: one sign-in, one check, however fast the finger. Signing out and refreshing the account keep the phase `.ready` while
/// the server answers, so the phase cannot say they are under way: each runs once per model while one is in flight.
@MainActor
enum RootActions {
    /// An action that leaves the phase as it was while it waits for the server.
    private enum Unphased: Hashable {
        case signOut, refreshAccount
    }

    /// An unphased action under way on one model.
    private struct Run: Hashable {
        let model: ObjectIdentifier
        let action: Unphased
    }

    private static var underWay: Set<Run> = []

    static func signIn(_ model: AppModel) async {
        guard model.phase == .signedOut else { return }
        await model.signIn()
    }

    static func retry(_ model: AppModel) async {
        guard case .problem = model.phase else { return }
        await model.connect()
    }

    static func signOut(_ model: AppModel, everywhere: Bool) async {
        guard model.phase == .ready else { return }
        await once(.signOut, on: model) { _ = await model.signOut(everywhere ? .everywhere : .thisDevice) }
    }

    static func refreshAccount(_ model: AppModel) async {
        guard model.phase == .ready else { return }
        await once(.refreshAccount, on: model) { await model.refreshAccount() }
    }

    /// Runs the action unless the same one is already under way on this model; a tap meanwhile does nothing.
    private static func once(_ action: Unphased, on model: AppModel, _ work: () async -> Void) async {
        let run = Run(model: ObjectIdentifier(model), action: action)
        guard underWay.insert(run).inserted else { return }
        defer { underWay.remove(run) }
        await work()
    }

    /// The No Workspace refresh: `refreshAccount` loads a workspace only for an account that was held back, so after an invitation
    /// is accepted only a new connection finds it. It serves that one screen only: connecting again while a workspace and its
    /// engine are open would replace the engine without stopping it, leaking it and its socket, and the two-step screen refreshes
    /// the account instead.
    static func reload(_ model: AppModel) async {
        guard RootScreen(model) == .noWorkspace else { return }
        await model.connect()
    }
}
