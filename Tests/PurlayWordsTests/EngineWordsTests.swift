import Foundation
import PurlayContract
import PurlayKit
import PurlayWords
import Testing

/// The sentences both apps say about what the engine reports, read from PurlayWords' own catalogue in each language.
@Suite("the engine's words, said alike by both apps")
struct EngineWordsTests {
    private static let problems: [ServerProblem] = [
        .unreachable, .notAPurlayServer, .rateLimited(retryAfter: 5),
        .appTooOld(ClientMinimum(appVersion: "9.0.0", contractVersion: nil, downloadUrl: nil)),
        .appTooOld(ClientMinimum(appVersion: nil, contractVersion: 2, downloadUrl: nil)),
        .serverTooOld(contract: 0), .unusableOrigin("ftp://x.test"),
    ]
    private static let signIns: [SignInError] = [
        .browserFailed("x"), .callbackRejected(.notOurs), .codeRejected, .rateLimited(retryAfter: nil),
        .refused(status: 403, code: .forbidden), .noSessionInAnswer, .unreachable(.offline),
        .storage(KeychainError(status: -25291, operation: "write")), .anotherPersonSignedIn(server: "chat.example.com"),
    ]
    private static let notices: [Notice.Kind] =
        [ServerAddress.Problem.empty, .unreadable, .notAWebAddress, .hasCredentials, .hasMoreThanAHost, .insecure]
        .map { .invalidAddress($0) } + signIns.map { .signInFailed($0) } + [
            .sessionExpired, .sessionEndsSoon(Date(timeIntervalSince1970: 0)), .sessionEndedByServer,
            .signedOutElsewhere, .serverNotTold, .signOutEverywhereFailed, .signOutFailed, .dataNotWiped,
            .accountErased, .accountPossiblyErased,
            .unsentLost(2),
            .unrestorable(1), .outboxCorrupt, .storageProblem, .storedSessionUnreadable, .originMismatch, .sendTooLong,
            .tooManyFiles,
            .readFailed, .loginItemFailed, .sendHeld(""), .sendHeld("# general"), .saveFailed, .fileNotWritten,
            .filesNotRead(["a.pdf", "b.png"]), .savedFull, .pinFailed, .pinsFull, .bookmarkFailed, .unreadFailed,
            .deepWorkFailed, .awayFailed, .groupFailed, .issueFailed, .joinFailed, .leaveFailed, .lastMember,
            .starFailed, .threadFailed, .resolveFailed, .followFailed, .editFailed, .deleteFailed, .profileFailed,
            .reactionFailed, .reactionLimit, .loadFailed, .knowledgeFailed, .knowledgeConflict,
        ]
    private static let uploads: [UploadFailure] = [
        .empty, .tooLarge, .imageTooLarge, .imageUnreadable, .unsupported, .storageFull(remainingBytes: 2048),
        .tooManyWaiting, .noConnection, .busy, .storageUnavailable, .sessionEnded, .noAccess, .unknown,
    ]

    private static let erasures: [EraseAccountResult] = [
        .reauthenticationRequired, .lastOwner(workspaceIDs: []),
        .lastOwner(workspaceIDs: [Uuid("0199155c-6200-7b7f-8c11-0000000000aa")!]), .confirmationMismatch, .refused,
        .sessionEnded, .unconfirmed, .failed,
    ]

    private static let reauthentications: [ReauthenticationResult] = [
        .differentPerson, .failed(.codeRejected), .notSignedIn,
    ]

    /// Every sentence the engine's words can say, with what it takes to say the ones that carry a value.
    private static var everySentence: [LocalizedStringResource] {
        EngineWords.fixed
            + problems.flatMap { [EngineWords.problem($0).title, EngineWords.problem($0).detail] }
            + signIns.compactMap(EngineWords.signIn) + notices.compactMap(EngineWords.notice)
            + uploads.map(EngineWords.upload) + erasures.compactMap(EngineWords.erasure)
            + reauthentications.compactMap(EngineWords.reauthentication)
    }

    private func text(_ resource: LocalizedStringResource, in language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test("every sentence is translated: in Turkish it is not the English one")
    func translated() {
        for sentence in Self.everySentence {
            let english = text(sentence, in: "en")
            let turkish = text(sentence, in: "tr")
            #expect(!english.isEmpty && !turkish.isEmpty)
            #expect(turkish != english, "not translated: \(english)")
        }
    }

    /// The server's product glossary (purlay/purlay `docs/GLOSSARY.md`, D-359) owns the product's words; the terms it says are
    /// never used, in Turkish.
    private static let glossaryNever: [(term: String, glossary: String)] = [
        ("iki faktörlü", "two-step verification is \"İki adımlı doğrulama\""),
        ("giriş yap", "sign in is \"Oturum aç\", never \"giriş\""),
        ("çıkış yap", "sign out is \"Oturumu kapat\", never \"çıkış yap\""),
    ]
    /// The glossary's terms the apps do not follow yet: the owner decides whether the apps follow them or the glossary
    /// changes first.
    private static let glossaryNeverPending: [(term: String, glossary: String)] = [
        ("Derin Çalışma", "Deep Work is \"Deep Work\" in both languages, never \"Derin Çalışma\" (D-348)"),
        ("konu", "a thread is \"Thread\", never \"konu\", which is a channel's topic (D-348)"),
    ]

    private func refuses(_ rules: [(term: String, glossary: String)]) {
        let turkishLocale = Locale(identifier: "tr")
        for sentence in Self.everySentence {
            let turkish = text(sentence, in: "tr").lowercased(with: turkishLocale)
            for rule in rules where turkish.contains(rule.term.lowercased(with: turkishLocale)) {
                Issue.record("\(turkish): \(rule.glossary)")
            }
        }
    }

    @Test("Turkish uses the server glossary's terms, never the ones it rules out")
    func glossaryTerms() {
        refuses(Self.glossaryNever)
    }

    @Test(
        "Turkish follows the glossary for Deep Work and Thread too",
        .disabled("pending the owner's decision on the glossary's Deep Work and Thread terms")
    )
    func glossaryTermsPending() {
        refuses(Self.glossaryNeverPending)
    }

    @Test("the words the two apps used to say differently are one: connecting is \"Bağlanıyor…\"")
    func oneWording() {
        #expect(text(EngineWords.connecting, in: "tr") == "Bağlanıyor…")
        #expect(text(EngineWords.connecting, in: "en") == "Connecting…")
    }

    @Test("every notice is a sentence a person can read, and none is the server's own words")
    func everyNoticeHasWords() {
        for kind in Self.notices {
            let words = EngineWords.notice(kind).map { text($0, in: "en") }
            #expect(words?.isEmpty == false, "\(kind)")
            #expect(words?.contains("Notice.Kind") == false, "\(kind)")
        }
    }

    @Test("a sign-in the person closed has no words: it is not a failure")
    func cancelledIsQuiet() {
        #expect(EngineWords.signIn(.cancelled) == nil)
        #expect(EngineWords.notice(.signInFailed(.cancelled)) == nil)
    }

    @Test("every problem with a server says what it is and what to do, and never the server's own text")
    func problemsSayWhat() {
        for problem in Self.problems {
            let words = EngineWords.problem(problem)
            for language in ["en", "tr"] {
                #expect(!text(words.title, in: language).isEmpty && !text(words.detail, in: language).isEmpty)
                #expect(!text(words.detail, in: language).contains("ftp://x.test"))
            }
        }
    }

    @Test("a sentence that takes a value says it, in each language")
    func values() {
        let minimum = ClientMinimum(appVersion: "9.0.0", contractVersion: nil, downloadUrl: nil)
        #expect(text(EngineWords.problem(.appTooOld(minimum)).detail, in: "en") == "It needs version 9.0.0 or newer.")
        #expect(text(EngineWords.problem(.appTooOld(minimum)).detail, in: "tr").contains("9.0.0"))
        let refused = EngineWords.signIn(.anotherPersonSignedIn(server: "chat.example.com"))
        #expect(refused.map { text($0, in: "en") } == "Sign out of chat.example.com first to use another account.")
        #expect(refused.map { text($0, in: "tr") }?.contains("chat.example.com") == true)
        let held = EngineWords.notice(.sendHeld("# general"))
        #expect(held.map { text($0, in: "tr") }?.contains("# general") == true)
    }

    @Test("a count is said in the form its number takes")
    func plurals() throws {
        let one = try #require(EngineWords.notice(.unsentLost(1)))
        let two = try #require(EngineWords.notice(.unsentLost(2)))
        #expect(text(one, in: "en").hasPrefix("1 unsent message was removed"))
        #expect(text(two, in: "en").hasPrefix("2 unsent messages were removed"))
        #expect(text(two, in: "tr").contains("2 gönderilmemiş mesaj"))
    }

    @Test("an erasure that did not happen says why, and one that did says nothing here: the notice says it")
    func erasures() {
        #expect(EngineWords.erasure(.erased) == nil)
        #expect(EngineWords.erasure(.possiblyErased) == nil, "the notice says it, as for an erasure")
        for result in Self.erasures {
            let words = EngineWords.erasure(result).map { text($0, in: "en") }
            #expect(words?.isEmpty == false, "\(result)")
        }
        #expect(EngineWords.notice(.accountErased).map { text($0, in: "tr") } == "Hesabınız silindi.")
        let probable = EngineWords.notice(.accountPossiblyErased).map { text($0, in: "en") } ?? ""
        #expect(!probable.contains("Sign in"), "an erased account that signs in again is a new account: not invited")
    }

    @Test("a wipe that failed says when it is tried again as the engine does: the next sign-out, or another's sign-in")
    func dataNotWipedSaysWhen() {
        let words = EngineWords.notice(.dataNotWiped).map { text($0, in: "en") }
        #expect(
            words
                == "Some of your data on this device could not be removed. Purlay tries again when you next sign out, or when someone else signs in here."
        )
    }

    @Test("a sign-in again that did not happen says why; one that did, or that the person closed, says nothing")
    func reauthentications() {
        #expect(EngineWords.reauthentication(.done) == nil)
        #expect(EngineWords.reauthentication(.failed(.cancelled)) == nil)
        for result in Self.reauthentications {
            #expect(EngineWords.reauthentication(result).map { text($0, in: "en") }?.isEmpty == false, "\(result)")
        }
    }

    @Test("the workspaces a last owner must hand over are counted in the form their number takes")
    func lastOwnerPlurals() throws {
        let ids = ["0199155c-6200-7b7f-8c11-0000000000aa", "0199155c-6200-7b7f-8c11-0000000000bb"].compactMap(Uuid.init)
        let one = try #require(EngineWords.erasure(.lastOwner(workspaceIDs: Array(ids.prefix(1)))))
        let two = try #require(EngineWords.erasure(.lastOwner(workspaceIDs: ids)))
        #expect(text(one, in: "en").hasPrefix("You are the last owner of 1 workspace with other people in it."))
        #expect(text(two, in: "en").hasPrefix("You are the last owner of 2 workspaces with other people in them."))
        #expect(text(two, in: "tr").contains("2 çalışma alanının son sahibisiniz"))
    }
}
