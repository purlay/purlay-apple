import PurlayContract
import PurlayKit
import SwiftUI
import Testing

@testable import PurlayMacUI

@MainActor
@Suite("the Mac's words")
struct MacWordsTests {
    @Test("an incident is named by its level and state, and the worst levels are red")
    func incidentWords() {
        let urgent = ChannelIncident(severity: .v1, status: .investigating)
        #expect(urgent.severityName == "SEV1" && urgent.tint == .red)
        #expect(ChannelIncident(severity: .v3, status: .mitigating).tint == .orange)
        #expect(ChannelIncident(severity: .unknown(7), status: .unknown("x")).severityName == "SEV7")
    }

    @Test("an unavailable bookmark action shows neutral feedback and an accepted bookmark shows none")
    func bookmarkActionFeedback() throws {
        let temporary = try #require(AppModel.BookmarkAddOutcome.temporarilyUnavailable.feedback)
        #expect(temporary.message == "Adding bookmarks is temporarily unavailable. Try again.")
        #expect(temporary.systemImage == "info.circle")
        #expect(AppModel.BookmarkAddOutcome.added.feedback == nil)
        let errors: [AppModel.BookmarkAddOutcome] = [.invalid, .full, .failed]
        for outcome in errors {
            #expect(outcome.feedback?.systemImage == "exclamationmark.circle")
        }
    }

    @Test("unavailable saved row actions have different feedback from actual errors")
    func savedActionFeedback() throws {
        let temporary = try #require(AppModel.SavedWriteOutcome.temporarilyUnavailable.feedback)
        #expect(temporary.message == "Saved message changes are temporarily unavailable. Try again.")
        #expect(temporary.systemImage == "info.circle")
        #expect(AppModel.SavedWriteOutcome.failed.feedback?.systemImage == "exclamationmark.circle")
        #expect(AppModel.SavedWriteOutcome.updated.feedback == nil)
    }
}
