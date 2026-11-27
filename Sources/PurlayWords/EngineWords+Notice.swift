import Foundation
import PurlayContract
import PurlayKit

extension EngineWords {
    /// What the model says that is not a screen of its own. `nil` says nothing: a sign-in the person closed is a choice. The
    /// switch names every kind, so a new kind does not compile until it has its sentence.
    public static func notice(_ kind: Notice.Kind) -> LocalizedStringResource? {
        switch kind {
        case .invalidAddress(let problem): address(problem)
        case .signInFailed(let error): signIn(error)
        case .sessionExpired: LocalizedStringResource("Your session has expired. Sign in again.", bundle: .module)
        case .sessionEndedByServer:
            LocalizedStringResource("You were signed out by the server. Sign in again.", bundle: .module)
        case .signedOutElsewhere: LocalizedStringResource("You were signed out.", bundle: .module)
        case .accountErased: LocalizedStringResource("Your account was deleted.", bundle: .module)
        case .sessionEndsSoon(let end):
            sessionEnds(end.formatted(date: .abbreviated, time: .shortened))
        case .serverNotTold:
            LocalizedStringResource(
                "You are signed out here. The server could not be reached, so this session stays valid there until it expires.",
                bundle: .module)
        case .dataNotWiped:
            LocalizedStringResource(
                "Some of your data on this device could not be removed. Purlay tries again at the next sign-in or sign-out.",
                bundle: .module)
        case .signOutEverywhereFailed:
            LocalizedStringResource("Could not sign out everywhere. You are still signed in.", bundle: .module)
        case .signOutFailed:
            LocalizedStringResource(
                "Could not sign out: the server could not be reached and this device could not forget the sign-in. You are still signed in.",
                bundle: .module)
        case .unsentLost(let count):
            LocalizedStringResource(
                "\(count) unsent messages were removed because you no longer have access to their channel.",
                bundle: .module)
        case .unrestorable(let count):
            LocalizedStringResource("\(count) unsent messages could not be restored.", bundle: .module)
        case .outboxCorrupt:
            LocalizedStringResource("Your unsent messages could not be read and were set aside.", bundle: .module)
        case .storageProblem:
            LocalizedStringResource(
                "Unsent messages can't be saved on this device right now. Sending still works.", bundle: .module)
        case .originMismatch:
            LocalizedStringResource(
                "The server refused this app's connection. Check the server's address.", bundle: .module)
        case .sendTooLong: LocalizedStringResource("That message is too long to send.", bundle: .module)
        case .tooManyFiles:
            LocalizedStringResource(
                "A message holds at most \(ContractConstants.attachmentsPerMessageMax) files. The rest were not added.",
                bundle: .module)
        case .readFailed:
            LocalizedStringResource(
                "Could not mark that as read. Check your connection and try again.", bundle: .module)
        case .loginItemFailed:
            LocalizedStringResource(
                "Could not change whether Purlay opens at login. Check System Settings > General > Login Items.",
                bundle: .module)
        case .sendHeld(let place):
            sendHeld(place)
        case .saveFailed: LocalizedStringResource("Could not change the save. Try again.", bundle: .module)
        case .fileNotWritten:
            LocalizedStringResource(
                "Could not save the file there. Choose another place and try again.", bundle: .module)
        case .filesNotRead(let names):
            filesNotRead(names.formatted(.list(type: .and)))
        case .savedFull:
            LocalizedStringResource(
                "You have saved as many messages as Purlay keeps. Let some go to save more.", bundle: .module)
        case .pinFailed: LocalizedStringResource("Could not change the pin. Try again.", bundle: .module)
        case .pinsFull:
            LocalizedStringResource(
                "This channel has as many pinned messages as it can hold. Unpin one first.", bundle: .module)
        case .bookmarkFailed: LocalizedStringResource("Could not remove the bookmark. Try again.", bundle: .module)
        case .unreadFailed:
            LocalizedStringResource(
                "Could not mark that as unread. Check your connection and try again.", bundle: .module)
        case .deepWorkFailed: LocalizedStringResource("Could not change Deep Work. Try again.", bundle: .module)
        case .awayFailed: LocalizedStringResource("Could not change your away status. Try again.", bundle: .module)
        case .groupFailed: LocalizedStringResource("Could not change your groups. Try again.", bundle: .module)
        case .issueFailed: LocalizedStringResource("Could not change that issue. Try again.", bundle: .module)
        case .joinFailed:
            LocalizedStringResource("Could not open that. Check your connection and try again.", bundle: .module)
        case .leaveFailed:
            LocalizedStringResource(
                "Could not leave the channel. Check your connection and try again.", bundle: .module)
        case .lastMember:
            LocalizedStringResource(
                "You are the last member of this private channel, so you can't leave it.", bundle: .module)
        case .starFailed: LocalizedStringResource("Could not change the star. Try again.", bundle: .module)
        case .threadFailed:
            LocalizedStringResource(
                "Could not load the thread. Check your connection and try again.", bundle: .module)
        case .resolveFailed:
            LocalizedStringResource(
                "Could not change whether this thread is resolved. Try again.", bundle: .module)
        case .followFailed:
            LocalizedStringResource(
                "Could not change whether you follow this thread. Try again.", bundle: .module)
        case .editFailed:
            LocalizedStringResource(
                "Could not change the message. Check your connection and try again.", bundle: .module)
        case .deleteFailed:
            LocalizedStringResource(
                "Could not delete the message. Check your connection and try again.", bundle: .module)
        case .profileFailed:
            LocalizedStringResource(
                "Could not save your profile. Check your connection and try again.", bundle: .module)
        case .reactionFailed:
            LocalizedStringResource(
                "Could not react to the message. Check your connection and try again.", bundle: .module)
        case .reactionLimit:
            LocalizedStringResource(
                "You can add at most \(ContractConstants.reactionsPerPersonMax) reactions to a message. Remove one to add another.",
                bundle: .module)
        case .loadFailed: LocalizedStringResource("Could not load messages. Check your connection.", bundle: .module)
        case .knowledgeFailed:
            LocalizedStringResource(
                "Could not change the question or decision. Check your connection and try again.", bundle: .module)
        case .knowledgeConflict:
            LocalizedStringResource(
                "Someone else changed this question or decision first. It now shows their change; review it and try again.",
                bundle: .module)
        }
    }

    private static func address(_ problem: ServerAddress.Problem) -> LocalizedStringResource {
        switch problem {
        case .empty: LocalizedStringResource("Type the address of your Purlay server.", bundle: .module)
        case .unreadable: LocalizedStringResource("That is not an address a browser would open.", bundle: .module)
        case .notAWebAddress: LocalizedStringResource("Use a web address, starting with https.", bundle: .module)
        case .hasCredentials:
            LocalizedStringResource("Leave the user name and password out of the address.", bundle: .module)
        case .hasMoreThanAHost:
            LocalizedStringResource("Give only the server's address, without a path.", bundle: .module)
        case .insecure: LocalizedStringResource("This server must be reached over https.", bundle: .module)
        }
    }

    private static func sessionEnds(_ when: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "Your session ends on \(when). Sign out and in again before then to stay connected.", bundle: .module)
    }

    private static func sendHeld(_ place: String) -> LocalizedStringResource {
        place.isEmpty
            ? LocalizedStringResource(
                "Your message was not sent: a file did not upload. Your words are back in the box.", bundle: .module)
            : LocalizedStringResource(
                "Your message to \(place) was not sent: a file did not upload. Your words are back in the box.",
                bundle: .module)
    }

    private static func filesNotRead(_ list: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "Could not read \(list). Check that it is still there, then attach it again.", bundle: .module)
    }
}
