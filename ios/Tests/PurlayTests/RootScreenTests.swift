import PurlayContract
import PurlayKit
import Testing

@testable import Purlay

@MainActor
@Suite("the screen of each phase")
struct RootScreenTests {
    @Test("each phase of the model has exactly one screen")
    func everyPhase() {
        #expect(RootScreen(phase: .launching, mustEnrolTwoFactor: false, hasWorkspace: true) == .busy(.connecting))
        #expect(RootScreen(phase: .checking, mustEnrolTwoFactor: false, hasWorkspace: true) == .busy(.connecting))
        #expect(RootScreen(phase: .signingIn, mustEnrolTwoFactor: false, hasWorkspace: true) == .busy(.signingIn))
        #expect(RootScreen(phase: .loading, mustEnrolTwoFactor: false, hasWorkspace: true) == .busy(.loading))
        #expect(RootScreen(phase: .signedOut, mustEnrolTwoFactor: false, hasWorkspace: true) == .signIn)
        #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: false, hasWorkspace: true) == .ready)
        #expect(
            RootScreen(phase: .problem(.unreachable), mustEnrolTwoFactor: false, hasWorkspace: true)
                == .problem(.unreachable))
    }

    @Test("a ready account is shown what it can do: two-step first, then no workspace, then the workspace")
    func readyScreens() {
        #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: true, hasWorkspace: false) == .twoFactorRequired)
        #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: true, hasWorkspace: true) == .twoFactorRequired)
        #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: false, hasWorkspace: false) == .noWorkspace)
        #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: false, hasWorkspace: true) == .ready)
        #expect(RootScreen(phase: .signedOut, mustEnrolTwoFactor: true, hasWorkspace: false) == .signIn)
    }

    @Test("the brand mark stands while something is under way and on Welcome, and nowhere else")
    func showsMark() {
        let shown: [RootScreen] = [.busy(.connecting), .busy(.signingIn), .busy(.loading), .signIn]
        let hidden: [RootScreen] = [.problem(.unreachable), .twoFactorRequired, .noWorkspace, .ready]
        for screen in shown { #expect(screen.showsMark, "\(screen)") }
        for screen in hidden { #expect(!screen.showsMark, "\(screen)") }
    }

    @Test("signing out, refreshing and reloading do nothing unless the account is ready")
    func guardedWhenNotReady() async {
        let harness = Harness([Harness.clientInfo()])
        await harness.model.connect()
        let before = await harness.transport.requests.count
        await RootActions.signOut(harness.model, everywhere: true)
        await RootActions.refreshAccount(harness.model)
        await RootActions.reload(harness.model)
        #expect(harness.model.phase == .signedOut)
        #expect(await harness.transport.requests.count == before)
    }

    @Test("an account with no workspace reloads through a new connection, and can sign out")
    func noWorkspaceAccount() async throws {
        let harness = Harness([
            Harness.clientInfo(), Harness.meWithoutWorkspace(),
            Harness.clientInfo(), Harness.meWithoutWorkspace(),
            ScriptedTransport.json(204, ""),
        ])
        try harness.rememberSession()
        await harness.model.connect()
        #expect(harness.model.phase == .ready)
        #expect(RootScreen(harness.model) == .noWorkspace)

        let before = await harness.transport.requests.count
        await RootActions.reload(harness.model)
        #expect(await harness.transport.requests.count > before, "a new handshake is made")
        #expect(RootScreen(harness.model) == .noWorkspace)

        await RootActions.signOut(harness.model, everywhere: false)
        #expect(harness.model.phase == .signedOut)
    }

    @Test("an account held back for two-step is not reloaded: its screen refreshes the account instead")
    func twoFactorNotReloaded() async throws {
        let harness = Harness([Harness.clientInfo(), Harness.meWithoutWorkspace(mustEnrolTwoFactor: true)])
        try harness.rememberSession()
        await harness.model.connect()
        #expect(RootScreen(harness.model) == .twoFactorRequired)
        let before = await harness.transport.requests.count
        await RootActions.reload(harness.model)
        #expect(await harness.transport.requests.count == before)
    }

    @Test("a server with no session kept asks the person to sign in")
    func signedOut() async {
        let harness = Harness([Harness.clientInfo()])
        await harness.model.connect()
        #expect(RootScreen(harness.model) == .signIn)
        #expect(harness.model.notices.isEmpty)
    }

    @Test(
        "each thing that can stand between the app and the server is its own problem screen, said in words for a person",
        arguments: [
            (ScriptedTransport.Step.fail(.offline), ServerProblem.unreachable),
            (ScriptedTransport.json(404, "{}"), .notAPurlayServer),
            (ScriptedTransport.json(429, "{}"), .rateLimited(retryAfter: nil)),
            (
                Harness.clientInfo(minApp: "9.0.0"),
                .appTooOld(ClientMinimum(appVersion: "9.0.0", contractVersion: 1, downloadUrl: nil))
            ),
            (Harness.clientInfo(contract: 0), .serverTooOld(contract: 0)),
            (Harness.clientInfo(appURL: "ftp://x.test"), .unusableOrigin("ftp://x.test")),
        ])
    func problems(step: ScriptedTransport.Step, expected: ServerProblem) async {
        let harness = Harness([step])
        await harness.model.connect()
        #expect(harness.model.phase == .problem(expected))
        #expect(RootScreen(harness.model) == .problem(expected))
        for language in ["en", "tr"] {
            let words = Words.problem(expected)
            let title = text(words.title, in: language)
            let detail = text(words.detail, in: language)
            #expect(!title.isEmpty && !detail.isEmpty)
            // A developer's description of the case is not a sentence for a person.
            for sentence in [title, detail] {
                #expect(!sentence.contains("ServerProblem") && !sentence.contains("unusableOrigin("))
                #expect(!sentence.contains("ftp://x.test"), "the server's own text is not shown")
            }
        }
    }

    @Test("trying again asks the server again, and a second tap before the answer asks nothing more")
    func retry() async {
        let harness = Harness([Harness.clientInfo()])
        await harness.transport.setOffline(true)
        await harness.model.connect()
        #expect(harness.model.phase == .problem(.unreachable))
        let asked = await harness.transport.requests.count
        await harness.transport.setOffline(false)
        async let first: Void = RootActions.retry(harness.model)
        async let second: Void = RootActions.retry(harness.model)
        _ = await (first, second)
        #expect(harness.model.phase == .signedOut)
        #expect(await harness.transport.requests.count == asked + 1, "one handshake, not two")
        await RootActions.retry(harness.model)
        #expect(await harness.transport.requests.count == asked + 1, "with no problem showing, retry asks nothing")
    }

    @Test("two quick taps on sign in open the browser once")
    func signInOnce() async {
        let harness = Harness([Harness.clientInfo()], browser: [.cancelled])
        await harness.model.connect()
        async let first: Void = RootActions.signIn(harness.model)
        async let second: Void = RootActions.signIn(harness.model)
        _ = await (first, second)
        #expect(await harness.authenticator.pages.count == 1)
        #expect(harness.model.phase == .signedOut)
        #expect(harness.model.notices.isEmpty, "closing the page is a choice, and nothing is said of it")
    }

    @Test("a browser that cannot be shown is said in a sentence, never as the platform's description")
    func browserFailure() async throws {
        let harness = Harness([Harness.clientInfo()], browser: [.failed("ASWebAuthenticationSessionError 2")])
        await harness.model.connect()
        await RootActions.signIn(harness.model)
        let notice = try #require(harness.model.notices.first)
        #expect(notice.kind == .signInFailed(.browserFailed("ASWebAuthenticationSessionError 2")))
        let words = try #require(Words.notice(notice.kind))
        #expect(text(words, in: "en") == "The browser could not be opened.")
        #expect(!text(words, in: "tr").contains("ASWebAuthenticationSessionError"))
        harness.model.dismiss(notice)
        #expect(harness.model.notices.isEmpty)
    }

    @Test(
        "an address the app cannot use is a problem screen with a sentence for it, and nothing is asked of the network")
    func unusableAddress() async throws {
        let harness = Harness([], serverAddress: "https://user:pw@x.test")
        await harness.model.launch()
        #expect(harness.model.phase == .problem(.unreachable))
        let notice = try #require(harness.model.notices.first)
        #expect(notice.kind == .invalidAddress(.hasCredentials))
        #expect(
            text(try #require(Words.notice(notice.kind)), in: "en")
                == "Leave the user name and password out of the address.")
        #expect(await harness.transport.requests.isEmpty)
    }
}
