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
        .storage(KeychainError(status: -25291, operation: "write")),
    ]
    private static let notices: [Notice.Kind] =
        [ServerAddress.Problem.empty, .unreadable, .notAWebAddress, .hasCredentials, .hasMoreThanAHost, .insecure]
        .map { .invalidAddress($0) } + signIns.map { .signInFailed($0) } + [
            .sessionExpired, .sessionEndsSoon(Date(timeIntervalSince1970: 0)), .sessionEndedByServer,
            .signedOutElsewhere, .serverNotTold, .signOutEverywhereFailed, .signOutFailed, .dataNotWiped,
            .unsentLost(2),
            .unrestorable(1), .outboxCorrupt, .storageProblem, .originMismatch, .sendTooLong, .tooManyFiles,
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

    /// Every sentence the engine's words can say, with what it takes to say the ones that carry a value.
    private static var everySentence: [LocalizedStringResource] {
        EngineWords.fixed
            + problems.flatMap { [EngineWords.problem($0).title, EngineWords.problem($0).detail] }
            + signIns.compactMap(EngineWords.signIn) + notices.compactMap(EngineWords.notice)
            + uploads.map(EngineWords.upload)
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
}
