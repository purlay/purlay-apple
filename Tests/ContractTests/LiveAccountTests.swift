import Foundation
import PurlayContract
import PurlayKit
import PurlayTestSupport
import Testing

/// The facts the fakes are most likely to get wrong, against the real server: each platform's minimum (D-340), the fresh
/// sign-in the erasure needs (D-356) and the erasure's own answers (D-139 §5).
@MainActor
@Suite("against a real server: the update gate, a fresh sign-in and erasing the account", .needsServer, .serialized)
struct LiveAccountTests {
    @Test(
        "an iOS app under the server's iOS minimum is refused at the handshake and by every request, while the Mac is served",
        .enabled(if: World.iOSMinimum != nil, "the server was started without an iOS minimum")
    )
    func iOSGate() async throws {
        let world = try World.load()
        let minimum = try #require(World.iOSMinimum)
        let iOS = HandshakeClient(
            transport: URLSessionTransport(), appVersion: world.appVersion, platform: .iOS, allowsLocalHTTP: true)
        guard case .appTooOld(let needed, _) = try await iOS.perform(world.server) else {
            Issue.record("the iOS app was served under its minimum")
            return
        }
        #expect(needed.appVersion == minimum)
        let mac = HandshakeClient(
            transport: URLSessionTransport(), appVersion: world.appVersion, platform: .macOS, allowsLocalHTTP: true)
        guard case .ready = try await mac.perform(world.server) else {
            Issue.record("the Mac was held to the iOS minimum")
            return
        }

        let persona = try world.persona("dogancan")
        do {
            _ = try await PurlayAPI(client: world.client(as: persona, platform: .iOS)).getMe()
            Issue.record("an iOS app under the minimum was served")
        } catch let error as APIError {
            #expect(error.status == 426)
            #expect(error.code == .clientTooOld)
            #expect(error.clientTooOld?.minAppVersion == minimum)
        }
        _ = try await PurlayAPI(client: world.client(as: persona, platform: .macOS)).getMe()
    }

    @Test(
        "the server says it judges the browser's own sign-in, and refuses a fresh sign-in for a browser it cannot date")
    func freshSignIn() async throws {
        let world = try World.load()
        let info = try await PurlayAPI(client: world.client(as: try world.persona("dogancan"))).getClientInfo()
        #expect(info.capabilities?.nativeFreshSignIn == true)
        // The demo's browser sessions were issued, not signed in: no sign-in time is recorded for them, so a page asking
        // `prompt=login` hands over nothing and the person is asked to sign in again. Without it, the code is made.
        let browser = PurlayAPI(client: world.client(as: try world.persona("carol")))
        let challenge = SignInAttempt.make()
        do {
            _ = try await browser.nativeAuthorize(
                body: NativeAuthorizeRequest(challenge: challenge.challenge, prompt: .login, state: challenge.state))
            Issue.record("a browser with no recorded sign-in was handed over as fresh")
        } catch let error as APIError {
            #expect(error.status == 403)
            #expect(error.code == .reauthenticationRequired)
        }
        let answer = try await browser.nativeAuthorize(
            body: NativeAuthorizeRequest(challenge: challenge.challenge, state: challenge.state))
        #expect(answer.redirect.contains("code="))
    }

    @Test("erasing with a username that is not the caller's is refused, and erases nothing")
    func wrongUsername() async throws {
        let world = try World.load()
        let persona = try world.outsider("frank")
        let api = PurlayAPI(client: world.client(as: persona))
        do {
            try await api.eraseMyAccount(body: EraseAccountRequest(confirm: persona.username + "-not"))
            Issue.record("an erasure with the wrong username was done")
        } catch let error as APIError {
            #expect(error.status == 400)
            #expect(error.code == .validationFailed)
        }
        #expect(try await api.getMe().user.username == persona.username)
    }

    /// The server's half of D-356 that the app's `erasureNeedsReauthentication` follows: an ordinary sign-in is never fresh
    /// enough to erase. The erasure that succeeds needs the browser to sign the person in again, a page this harness cannot
    /// drive (the demo's people have no password and the demo sends no mail); TD-017 says so.
    @Test(
        "a session the app was just handed by a browser the server cannot date cannot erase the account, and nothing is erased"
    )
    func handedOverSessionCannotErase() async throws {
        let world = try World.load()
        let persona = try world.outsider("gwen")
        let browser = SignedInBrowser(api: PurlayAPI(client: world.client(as: persona)), issued: .init())
        let session = try await NativeSignIn(
            transport: URLSessionTransport(), appVersion: world.appVersion, platform: world.identity.platform,
            authenticator: browser, store: InMemorySessionStore(), deviceName: "Contract Test Mac"
        ).signIn(to: world.server, origin: world.server)
        let own = World.Persona(userID: persona.userID, username: persona.username, session: session.cookie)
        let api = PurlayAPI(client: world.client(as: own))
        do {
            try await api.eraseMyAccount(body: EraseAccountRequest(confirm: persona.username))
            Issue.record("a session handed over from an undated browser erased the account")
        } catch let error as APIError {
            #expect(error.status == 403)
            #expect(error.code == .reauthenticationRequired)
        }
        #expect(try await api.getMe().user.username == persona.username)
        try await api.logout()
    }
}
