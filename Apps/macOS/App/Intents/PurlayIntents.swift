import AppIntents
import PurlayContract
import PurlayKit
import PurlayMacUI
import PurlayWords

// What Shortcuts, Spotlight and Siri can ask of Purlay. Each intent calls the model, as a menu item does; nothing here decides
// what the app does. The identifiers below (type names, the entity's id, the enum's raw values, the phrases) are kept by people's
// saved shortcuts: add to them, never rename them.

/// The main window, opened again if it was closed: set by the window itself, which owns `openWindow`.
@MainActor
final class MainWindowOpener {
    var open: (() -> Void)?
}

/// A refused shortcut, said in the app's words.
struct PurlayIntentError: Error, CustomLocalizedStringResourceConvertible {
    let refusal: ShortcutRefusal

    var localizedStringResource: LocalizedStringResource {
        switch refusal {
        case .notSignedIn: "Open Purlay and sign in first."
        case .conversationGone: "That conversation is not in your sidebar any more."
        case .notSent: SharedWords.messageNotSent
        }
    }
}

/// What a shortcut asks of the sessions (`DesktopSessions`' shortcut methods decide it), its refusal said in the app's words.
@MainActor
private func asking<T>(_ work: () async throws -> T) async throws -> T {
    do { return try await work() } catch let refusal as ShortcutRefusal { throw PurlayIntentError(refusal: refusal) }
}

// MARK: Conversations

struct ConversationEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Conversation"
    static let defaultQuery = ConversationQuery()

    /// The channel's id: stable for as long as the conversation exists.
    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ channel: Channel) {
        id = channel.id.value
        name = AttentionWords.place(channel)
    }
}

/// The conversations of the workspace in front, in the sidebar's order.
struct ConversationQuery: EntityStringQuery {
    @Dependency private var sessions: DesktopSessions

    @MainActor
    private func conversations() async throws -> [ConversationEntity] {
        try await asking { try await sessions.shortcutConversations() }.map(ConversationEntity.init)
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ConversationEntity] {
        let wanted = Set(identifiers)
        return try await conversations().filter { wanted.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [ConversationEntity] {
        try await conversations().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ConversationEntity] { try await conversations() }
}

struct OpenConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Conversation"
    static let description = IntentDescription("Opens a channel or direct conversation in Purlay.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Conversation") var conversation: ConversationEntity
    @Dependency private var sessions: DesktopSessions
    @Dependency private var mainWindow: MainWindowOpener

    @MainActor
    func perform() async throws -> some IntentResult {
        let (model, channel) = try await asking { try await sessions.shortcutConversation(conversation.id) }
        mainWindow.open?()
        await model.showChannel(channel)
        return .result()
    }
}

struct SendMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "Send a Message"
    static let description = IntentDescription(
        "Sends a message to a channel or direct conversation. It waits in the outbox while you are offline.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Conversation") var conversation: ConversationEntity
    @Parameter(title: "Message", inputOptions: String.IntentInputOptions(multiline: true)) var text: String
    @Dependency private var sessions: DesktopSessions

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$text) to \(\.$conversation)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Words leave in the person's name from the background, so the person is asked before they go.
        try await requestConfirmation(actionName: .send, dialog: "Send this message to \(conversation.name)?")
        try await asking { try await sessions.shortcutSend(text, to: conversation.id) }
        return .result()
    }
}

// MARK: Inbox and Deep Work

struct OpenInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Inbox"
    static let description = IntentDescription("Shows your mentions, direct messages and threads in Purlay.")
    static let supportedModes: IntentModes = .foreground

    @Dependency private var sessions: DesktopSessions
    @Dependency private var mainWindow: MainWindowOpener

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = try await asking { try await sessions.shortcutModel() }
        mainWindow.open?()
        await model.openInbox()
        return .result()
    }
}

enum DeepWorkLengthOption: String, AppEnum {
    case halfHour, hour, twoHours, untilTomorrow

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Length"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .halfHour: DisplayRepresentation(title: "30 Minutes"), .hour: DisplayRepresentation(title: "1 Hour"),
        .twoHours: DisplayRepresentation(title: "2 Hours"),
        .untilTomorrow: DisplayRepresentation(title: "Until Tomorrow"),
    ]

    var length: DeepWork.Length {
        switch self {
        case .halfHour: .halfHour
        case .hour: .hour
        case .twoHours: .twoHours
        case .untilTomorrow: .untilTomorrow
        }
    }
}

struct StartDeepWorkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Deep Work"
    static let description = IntentDescription("Quiets Purlay's interruptions for a focus session.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Length", default: .hour) var length: DeepWorkLengthOption
    @Dependency private var sessions: DesktopSessions

    @MainActor
    func perform() async throws -> some IntentResult {
        try await asking { try await sessions.shortcutModel() }.startDeepWork(length.length)
        return .result()
    }
}

struct EndDeepWorkIntent: AppIntent {
    static let title: LocalizedStringResource = "End Deep Work"
    static let description = IntentDescription("Ends the focus session, so Purlay tells you what needs you again.")
    static let supportedModes: IntentModes = .background

    @Dependency private var sessions: DesktopSessions

    @MainActor
    func perform() async throws -> some IntentResult {
        try await asking { try await sessions.shortcutModel() }.endDeepWork()
        return .result()
    }
}

struct PurlayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenInboxIntent(),
            phrases: ["Open my \(.applicationName) inbox", "Show \(.applicationName) inbox"],
            shortTitle: "Open Inbox", systemImageName: "tray")
        AppShortcut(
            intent: OpenConversationIntent(), phrases: ["Open a conversation in \(.applicationName)"],
            shortTitle: "Open Conversation", systemImageName: "bubble.left.and.bubble.right")
        AppShortcut(
            intent: SendMessageIntent(), phrases: ["Send a message with \(.applicationName)"],
            shortTitle: "Send a Message", systemImageName: "paperplane")
        AppShortcut(
            intent: StartDeepWorkIntent(), phrases: ["Start Deep Work in \(.applicationName)"],
            shortTitle: "Start Deep Work", systemImageName: "moon")
        AppShortcut(
            intent: EndDeepWorkIntent(), phrases: ["End Deep Work in \(.applicationName)"],
            shortTitle: "End Deep Work", systemImageName: "sun.max")
    }
}
