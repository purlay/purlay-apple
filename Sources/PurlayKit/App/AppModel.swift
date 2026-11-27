import Foundation
import Observation
import PurlayContract

/// What a person is told that is not a screen of its own: a sentence, said once. A view turns each into words in the language of the
/// app; the model never writes English at a person (the server's own `message` is for a log).
public struct Notice: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case invalidAddress(ServerAddress.Problem)
        case signInFailed(SignInError)
        case sessionExpired
        /// The session lasts a fixed time from sign-in: said a few days before, so the end is not a surprise.
        case sessionEndsSoon(Date)
        case sessionEndedByServer
        case signedOutElsewhere
        /// The person's account was erased, and this app signed out with it.
        case accountErased
        /// The session ended after an erasure whose answer never came: the account is very likely gone, and this app signed
        /// out and removed what it kept of the person (`EraseAccountResult.possiblyErased`).
        case accountPossiblyErased
        /// This device is signed out and the server could not be told: its session lives until it expires or is ended from elsewhere.
        case serverNotTold
        case signOutEverywhereFailed
        /// Some of what the app kept of the person on this device could not be removed: it is tried again at the next sign-out,
        /// or the next sign-in of another person.
        case dataNotWiped
        /// Signing out here could neither reach the server nor remove the sign-in from this Mac: still signed in.
        case signOutFailed
        case unsentLost(Int)
        case unrestorable(Int)
        case outboxCorrupt
        case storageProblem
        case originMismatch
        case sendTooLong
        case tooManyFiles
        case readFailed
        case loginItemFailed
        /// A send that waited for its files was held: a file failed. The words are back in the box of the place named.
        case sendHeld(String)
        case saveFailed
        /// A received file could not be written where the person chose.
        case fileNotWritten
        /// Files the person chose that could not be read: gone, or not opened to the app. Named, so they know which.
        case filesNotRead([String])
        case savedFull
        case pinFailed
        case pinsFull
        case bookmarkFailed
        case unreadFailed
        case deepWorkFailed
        case awayFailed
        case groupFailed
        case issueFailed
        case joinFailed
        case leaveFailed
        case lastMember
        case starFailed
        case threadFailed
        case resolveFailed
        case followFailed
        case editFailed
        case deleteFailed
        case profileFailed
        case reactionFailed
        /// The person already has as many reactions on the message as one may (D-249).
        case reactionLimit
        case loadFailed
        case knowledgeFailed
        /// Somebody else changed a thread's question or decision first: it was read again, and nothing was written over theirs.
        case knowledgeConflict
    }

    public let id: Int
    public let kind: Kind
}

/// What stands between the app and a server it can talk to.
public enum ServerProblem: Equatable, Sendable {
    case unreachable
    case notAPurlayServer
    case rateLimited(retryAfter: Int?)
    /// The server needs a newer app than this one.
    case appTooOld(ClientMinimum)
    /// The server is older than this app can talk to.
    case serverTooOld(contract: Int)
    case unusableOrigin(String)
}

/// The app's one model: where it is pointed, whether a person is signed in, what they see, and what they do. A view reads it and calls
/// it, and never reaches the network. A person never stands in front of a screen that is not one of these phases.
@MainActor
@Observable
public final class AppModel {
    public enum Phase: Equatable, Sendable {
        case launching
        case checking
        case problem(ServerProblem)
        case signedOut
        case signingIn
        /// Signed in and reading what the first screen needs.
        case loading
        case ready
    }

    var chatRouteUnavailable = false
    public internal(set) var settingsPage: SettingsPage = .general
    public private(set) var phase: Phase = .launching {
        didSet { onPhaseChange?() }
    }
    @ObservationIgnored var onPhaseChange: (() -> Void)?
    /// The session ended here. `removedDataOf`: the id of the person who signed out or whose account was erased, and whose data
    /// this session removed; nil when the server ended it (that data waits for their next sign-in).
    @ObservationIgnored var onSessionEnded: ((_ removedDataOf: String?) -> Void)?
    /// The other sessions of this app on the same server (the Mac's workspaces), which share one credential and one person
    /// (ADR 0011). None on iOS.
    @ObservationIgnored var sharedServer: SharedServer?
    private let preferredWorkspaceID: Uuid?
    public private(set) var server: ServerAddress?
    public private(set) var serverInfo: ClientInfo?
    private var sessionMe: MeResponse?
    public internal(set) var me: MeResponse? {
        get {
            if let sessionOwner { return sessionOwner.me }
            return sessionMe
        }
        set { if let sessionOwner { sessionOwner.me = newValue } else { sessionMe = newValue } }
    }
    public private(set) var workspace: Workspace?
    public internal(set) var selectedChannel: Uuid? {
        // Leaving a channel marked unread lets it go: the next visit reads it as usual (D-212).
        didSet { if unreadHold != selectedChannel { unreadHold = nil } }
    }
    public private(set) var notices: [Notice] = []

    // What the engine holds, copied when it changes so a view observes it.
    public private(set) var chat = ChatState()
    public private(set) var pending: [PendingMessage] = []
    public private(set) var connection: Connection.Status = .idle
    public private(set) var degraded: [Uuid: DegradedReason] = [:]

    let environment: AppEnvironment
    var origin: ServerAddress?
    private var manager: SessionManager?
    var engine: Engine?
    var api: PurlayAPI?
    @ObservationIgnored weak var sessionOwner: AppModel?
    @ObservationIgnored private var conversationWindows: [WeakConversationModel] = []
    /// What is ending the session, one at a time: a sign-out, or an erasure of the account (asked here, or said by the
    /// socket). One asked for meanwhile waits for it instead of racing it, so the wipers and `onSessionEnded` run once. Both
    /// leave the phase `.ready` while the server answers, so the phase cannot say they are under way. While one runs, a session
    /// the server ends is its to say (an erasure's `SESSION_ENDED` can come before its `204`), so the observer leaves it alone.
    private enum Ending {
        case signingOut(Task<SessionManager.SignOutResult, Never>)
        case erasing(Task<EraseAccountResult, Never>)
    }
    @ObservationIgnored private var ending: Ending?
    /// The socket said `account-deleted` while this app's erasure was out: the account is gone, whatever its answer says.
    @ObservationIgnored private var erasedBySocket = false
    /// An erasure left and its answer never came (`EraseAccountResult.unconfirmed`). Until the session ends, an end the
    /// server gives without a reason (a `401`, a refused socket) is read as that erasure's (`possiblyErased`), never as "sign
    /// in again", which would make a new account. A reason the socket gives settles it: `account-deleted` is the erasure,
    /// `signed-out` and `expired` prove the account was still there. A successful read does not, since the erasure may still
    /// be waiting on the server to commit. Kept as the person's id under the server (`unconfirmedErasureKey(for:)`) in the
    /// preferences every session of the app shares, so whichever of the Mac's workspaces hears the end applies it, and a
    /// relaunch keeps it; it counts only for the same person, and a launch without a session or a new sign-in forgets it.
    private var erasureUnconfirmed: Bool {
        guard let server, let person = personHere else { return false }
        return environment.sharedPreferences.string(for: Self.unconfirmedErasureKey(for: server)) == person
    }

    static func unconfirmedErasureKey(for server: ServerAddress) -> String {
        "purlay.erasure.unconfirmed.\(server.description)"
    }

    private func markErasureUnconfirmed() {
        guard let server, let person = me?.user.id.value else { return }
        environment.sharedPreferences.set(person, for: Self.unconfirmedErasureKey(for: server))
    }

    private func forgetUnconfirmedErasure() {
        guard let server else { return }
        environment.sharedPreferences.set(nil, for: Self.unconfirmedErasureKey(for: server))
    }

    /// Who this session is: the person read, or while it is read, the owner of what it kept.
    var personHere: String? {
        me?.user.id.value ?? (heldSession == nil ? nil : environment.owner.load())
    }

    /// A sign-out or an erasure is ending this session.
    var isEndingSession: Bool { ending != nil }

    /// The session in use here: the credential the Keychain keeps once it is known whose it is.
    @ObservationIgnored private(set) var heldSession: StoredSession?
    /// A browser sign-in's session on the Mac, not yet kept: it is written to the Keychain once `/api/me` says whose it is,
    /// and only if it is the person the server's other workspaces hold (ADR 0011). A first read that fails leaves it here,
    /// and Try Again (`connect()`) reads again with it; a model that lets it go without keeping it ends it on the server.
    @ObservationIgnored private var unkeptCredential: StoredSession?
    /// A browser sign-in here is not yet known to be whose.
    var hasUnkeptSession: Bool { unkeptCredential != nil }
    /// A sign-out is under way: a send waiting for its files does not go, so nothing is delivered after the person accepted
    /// that what is unsent is removed. Released if the sign-out does not happen.
    @ObservationIgnored var sendsHeld = false
    /// An account read under way: one asked for meanwhile (the Mac's Check Again beside its activation) waits for it and
    /// shares its answer instead of asking the server again.
    @ObservationIgnored var refreshingAccount: Task<Void, Never>?
    /// A sign-in again under way: one asked for meanwhile waits for it and shares its answer, so one browser is opened.
    @ObservationIgnored private var reauthenticating: Task<ReauthenticationResult, Never>?
    /// When this run signed the person in through the browser (`signIn`, `reauthenticate`); nil for a session restored at
    /// launch, whose age the app does not know.
    private var signedInAt: Date?
    /// How long before the server's limit a sign-in is no longer called recent: the request takes time to arrive.
    static let erasureSignInMargin: TimeInterval = 60
    private var observation: Task<Void, Never>?
    private var noticeCounter = 0
    private var launched = false
    private var warnedOfExpiry = false
    private static let sessionWarning: TimeInterval = 3 * 86_400
    /// The newest message of each channel that was marked read from here, so the same one is not asked for twice.
    private var markedRead: [Uuid: Uuid] = [:]
    private var marking = Set<Uuid>()
    /// After a read the server refused, nothing is asked again for a while unless the person's own seeing changes: a failing server is
    /// not asked on every frame.
    private var readRetryAfter: [Uuid: Date] = [:]
    private static let readRetryDelay: TimeInterval = 30
    /// The window is in front of the person (D-143): only then is anything read.
    public private(set) var isActive = true
    /// The newest message is in view: reading what is not seen is not reading.
    public private(set) var atBottom = true

    let uploadIDs: MessageIDGenerator

    // MARK: People

    /// The people of the workspace, and the members of the private channels that were opened: who an `@` could reach.
    private var sessionPeople: [User] = []
    public internal(set) var workspacePeople: [User] {
        get {
            if let sessionOwner { return sessionOwner.workspacePeople }
            return sessionPeople
        }
        set { if let sessionOwner { sessionOwner.workspacePeople = newValue } else { sessionPeople = newValue } }
    }
    var channelPeople: [Uuid: [User]] = [:]
    /// What each member of the workspace says of themselves (title, status, time zone), as the member list last gave it.
    var memberProfiles: [Uuid: WorkspaceMember] = [:]

    // MARK: Threads

    /// Whether the person is told of new replies to the open thread, and whether that is known yet.
    public enum FollowState: Equatable, Sendable {
        case reading
        case known(Bool)
        case failed
    }

    /// The open thread: one at a time, in the panel beside the channel it is in.
    public internal(set) var thread: ThreadWindow?
    /// The thread could not be read: the panel says so and offers another try, instead of waiting for what is not coming.
    public internal(set) var threadLoadFailed = false
    /// The last call for the channel's message box to take the keyboard; the box answers each new one.
    public internal(set) var composerFocus = ComposerFocusRequest()
    /// The message whose reaction picker was asked for from the menu; its row opens the picker and clears this.
    public var reactionPickerTarget: Uuid?
    /// Channels whose newest messages could not be read, for the same reason.
    public internal(set) var channelLoadFailed: Set<Uuid> = []
    public internal(set) var threadFollow: FollowState = .reading
    var threadRootCopy: Message?
    var threadGeneration = 0
    var threadMarked: [Uuid: Uuid] = [:]
    /// Roots whose questions and decisions are being written: one write at a time each, since each carries the version it read.
    public internal(set) var knowledgeSaving: Set<Uuid> = []

    // MARK: The inbox

    public enum InboxFilter: Sendable, Equatable {
        case all, unread
    }

    public enum InboxStatus: Sendable, Equatable {
        case idle, loading, loaded, failed
    }

    public var inboxOpen = false
    public internal(set) var unresolvedOpen = false
    public internal(set) var issuesOpen = false
    public internal(set) var issueFilter: IssueFilter = .open
    public internal(set) var issuesStatus: InboxStatus = .idle
    public internal(set) var issueItems: [Issue] = []
    public internal(set) var issuesLoadingMore = false
    var issuesCursor: Uuid?
    /// What the server said of each link of each message, `nil` for a link it had no card for: kept for this session.
    var linkPreviews: [String: LinkPreviewCard?] = [:]
    var linkPreviewFailures: [String: Date] = [:]
    var issuesGeneration = 0
    public internal(set) var unresolvedChannelID: Uuid?
    public internal(set) var unresolvedItems: [Message] = []
    public internal(set) var unresolvedLoading = false
    public internal(set) var unresolvedFailed = false
    public internal(set) var unresolvedUpdating: Set<Uuid> = []
    public internal(set) var unresolvedFilter: UnresolvedFilter = .all
    var unresolvedCursor: Uuid?
    var unresolvedGeneration = 0
    public internal(set) var inboxFilter: InboxFilter = .all
    public internal(set) var inboxCategory: Inbox.Category = .all
    public internal(set) var inboxStatus: InboxStatus = .idle
    public internal(set) var inboxRows: [InboxRow] = []

    /// What the server told, as it told it: rows are made from it again whenever it changes, since a thread's replies of one day may
    /// run over two pages.
    var inboxNotes: [PurlayContract.Notification] = []
    var inboxCursor: Uuid?
    /// Additive support is discovered for the active server, independently of its release version.
    public var inboxFiltersLocally: Bool { serverInfo?.capabilities?.notificationTypeFilters != true }
    var inboxGeneration = 0
    public internal(set) var inboxLoadingMore = false

    // MARK: The inbox's updates (D-286)

    public internal(set) var updatesStatus: InboxStatus = .idle
    public internal(set) var updateRows: [InboxUpdateRow] = []
    /// Every unread notice of the person's in the workspace, as the server counts them: not the page's.
    public internal(set) var updatesUnread = 0
    var updatesCursor: Uuid?
    var updatesGeneration = 0
    public internal(set) var updatesLoadingMore = false

    // MARK: The keyboard's moves

    var keyboardRow: Uuid?

    // MARK: Saved, pinned, and the last message

    /// What the person saved, by message, and in which state.
    private var sessionSavedIDs: [Uuid: SavedState] = [:]
    public internal(set) var savedIDs: [Uuid: SavedState] {
        get {
            if let sessionOwner { return sessionOwner.savedIDs }
            return sessionSavedIDs
        }
        set { if let sessionOwner { sessionOwner.savedIDs = newValue } else { sessionSavedIDs = newValue } }
    }
    /// The pins of each channel that was opened, newest first as the server gives them.
    private var sessionPins: [Uuid: [PinnedMessage]] = [:]
    var pins: [Uuid: [PinnedMessage]] {
        get {
            if let sessionOwner { return sessionOwner.pins }
            return sessionPins
        }
        set { if let sessionOwner { sessionOwner.pins = newValue } else { sessionPins = newValue } }
    }
    /// The bookmarks of each channel that was opened, oldest first as the server gives them (D-218).
    private var sessionBookmarks: [Uuid: [ChannelBookmark]] = [:]
    var bookmarks: [Uuid: [ChannelBookmark]] {
        get {
            if let sessionOwner { return sessionOwner.bookmarks }
            return sessionBookmarks
        }
        set { if let sessionOwner { sessionOwner.bookmarks = newValue } else { sessionBookmarks = newValue } }
    }
    /// The channel a bookmark is being added to in this window: the sheet is open while it is set.
    public var addingBookmark: Uuid?
    /// The open channel, marked unread from a message here: not read again while it stays open (D-212).
    var unreadHold: Uuid?
    public internal(set) var savedItems: [SavedItem] = []
    public enum SavedStatus: Equatable, Sendable { case idle, loading, loaded, failed }
    public internal(set) var savedStatus: SavedStatus = .idle
    public internal(set) var loadingMoreSaved = false
    public internal(set) var savedPaginationFailed = false
    var savedState: SavedState = .inProgress
    var savedCursor: Uuid?
    var savedGeneration = 0
    var contextGeneration = 0
    public var savedFilter: SavedState { savedState }
    public var savedLoading: Bool { savedStatus == .loading || loadingMoreSaved }
    public var savedFailed: Bool { savedStatus == .failed || savedPaginationFailed }
    public internal(set) var savedUpdating: Set<Uuid> = []
    /// The message whose words are being changed, if any: one at a time.
    public internal(set) var editing: Uuid?
    /// Reactions on their way, as message id and emoji: a double click is one request.
    @ObservationIgnored var reacting: Set<String> = []
    /// An older page of the open channel is on its way.
    public internal(set) var loadingOlder = false

    // MARK: Files

    struct Place: Hashable {
        let channel: Uuid
        let parent: Uuid?
    }

    /// Files chosen for a message, by the place they were chosen for: a channel's box, or one thread's. Moving to another channel loses none.
    var uploadsByPlace: [Place: [Upload]] = [:]
    /// What a file that has not gone, or has not gone yet, is made of: kept only so a retry can send the same bytes under the same id.
    var uploadBytes: [Uuid: Data] = [:]
    var attachmentCache: [String: Data] = [:]
    var attachmentCacheOrder: [String] = []
    var attachmentCacheBytes = 0

    /// Counts the times words were handed back, so a box on the screen knows to ask.
    public internal(set) var handedBackCount = 0

    var waitingSends: [Place: String] = [:]
    @ObservationIgnored var handedBack: [Place: String] = [:]

    // MARK: What is on show

    /// The palette (`⌘K`) and the search sheet are open. A command of the menu asks for them; the window shows them.
    public var paletteOpen = false
    public var searchOpen = false
    public var pinsOpen = false
    public var remindersOpen = false { didSet { if remindersOpen { closePages(except: .reminders) } } }
    public var reminderTarget: Message?
    public var deletionTarget: Message?
    var deletingMessages: Set<Uuid> = []
    var storedReminders: [MessageReminder] = []
    var loadingReminders = false
    var failedReminders = false
    var reminderGeneration = 0
    public var scheduledOpen = false { didSet { if scheduledOpen { closePages(except: .scheduled) } } }
    public internal(set) var scheduledItems: [ScheduledMessage] = []
    public internal(set) var scheduledLoading = false
    public internal(set) var scheduledFailed = false
    var scheduledGeneration = 0
    public var savedOpen = false { didSet { if savedOpen { closePages(except: .saved) } } }
    public var shortcutsOpen = false

    /// The pages that stand in the place of a channel: one at a time, and none once a channel is chosen.
    enum Page { case inbox, unresolved, issues, reminders, scheduled, saved, drafts }

    func closePages(except page: Page? = nil) {
        if page != .inbox { inboxOpen = false }
        if page != .unresolved { unresolvedOpen = false }
        if page != .issues { issuesOpen = false }
        if page != .reminders { remindersOpen = false }
        if page != .scheduled { scheduledOpen = false }
        if page != .saved { savedOpen = false }
        if page != .drafts { draftsOpen = false }
    }
    public var draftsOpen = false { didSet { if draftsOpen { closePages(except: .drafts) } } }
    public private(set) var draftRevision = 0

    /// Which channels have a draft, and which have been looked at: not observed, since `draftRevision` says when it changed.
    final class DraftIndex {
        var scanned: Set<Uuid> = []
        var drafted: Set<Uuid> = []
    }
    @ObservationIgnored let draftIndex = DraftIndex()

    /// A draft changed: `channel` is the one whose own box it is, if it is a channel's and not a reply's.
    func draftDidChange(channel: Uuid? = nil) {
        if let sessionOwner {
            sessionOwner.draftDidChange(channel: channel)
            return
        }
        if let channel { noteDraft(of: channel) }
        draftRevision &+= 1
        for window in liveConversationWindows {
            if let channel { window.noteDraft(of: channel) }
            window.draftRevision &+= 1
        }
    }

    // MARK: Search

    public enum SearchStatus: Equatable, Sendable {
        case idle
        case searching
        case done
        case failed
        /// The server would not take these filters as they stand: a repository not named owner/name, say.
        case refused
    }

    /// Where the feed is told to look: a message found, to be scrolled to and marked. The number says it again for the same message.
    public struct Focus: Equatable, Sendable {
        public let message: Uuid
        public let sequence: Int
    }

    public internal(set) var searchQuery = ""
    public internal(set) var searchChannelID: Uuid?
    public internal(set) var searchSenderID: Uuid?
    /// The filters past where and from whom: thread status, questions, code or files, days and a repository.
    public internal(set) var searchFilters = SearchFilters()
    public internal(set) var recentSearches: [MessageSearch] = []
    /// What the search field opens with, including the space after a channel scope such as `in:design `.
    public internal(set) var searchInput = ""
    public internal(set) var searchResults: [Message] = []
    /// What the workspace's find says of the words in the issues module, beside the messages (D-285).
    public internal(set) var searchIssues: [FindHit] = []
    public internal(set) var searchStatus: SearchStatus = .idle
    public internal(set) var focus: Focus?
    var searchCursor: Uuid?
    var searchGeneration = 0
    var loadingMoreResults = false
    var focusSequence = 0
    var navigationGeneration = 0
    /// The person's named searches in this workspace, newest first, as the server keeps them.
    public internal(set) var savedSearches: [SavedSearch] = []
    public internal(set) var savedSearchesStatus: SavedStatus = .idle
    var savedSearchGeneration = 0

    // MARK: What needs the person

    var attention = Attention()
    var lastBadge: Int?
    var deepWorkTimer: (() -> Void)?
    /// A re-read waiting to be tried again, by what it reads; each value cancels its timer.
    var refreshRetry: [Refresh: () -> Void] = [:]

    var deepWorkChange = 0
    var awayChange = 0

    public init(_ environment: AppEnvironment, workspaceID: Uuid? = nil) {
        self.environment = environment
        self.preferredWorkspaceID = workspaceID
        uploadIDs = MessageIDGenerator(now: environment.clock)
        launchAtLogin = environment.loginItem.status
    }

    // MARK: What a view reads

    /// The channels of the workspace, by name, direct conversations by their people.
    public var channels: [Channel] {
        chat.channels.values.sorted { Self.title($0).localizedStandardCompare(Self.title($1)) == .orderedAscending }
    }

    public static func title(_ channel: Channel) -> String { channel.title }

    /// What the sidebar lists: starred, channels and conversations the person is in.
    private var sessionSidebarLayout = SidebarLayout()
    public internal(set) var sidebarLayout: SidebarLayout {
        get { sessionOwner?.sidebarLayout ?? sessionSidebarLayout }
        set { if let sessionOwner { sessionOwner.sidebarLayout = newValue } else { sessionSidebarLayout = newValue } }
    }
    public var sidebar: [SidebarSection] { sidebarLayout.sections(Array(chat.channels.values)) }

    /// Public channels the person could join: what Browse lists.
    public var joinableChannels: [Channel] { Sidebar.joinable(Array(chat.channels.values)) }

    public var window: ChannelWindow? {
        selectedChannel.flatMap { chat.windows[$0] }
    }

    /// What was sent to the open channel and is not yet known to have arrived. A reply is the thread's, not the feed's.
    public var selectedPending: [PendingMessage] {
        pending.filter { $0.channelID == selectedChannel && $0.parentID == nil }
    }

    // MARK: Notices

    func say(_ kind: Notice.Kind) {
        noticeCounter += 1
        notices.append(Notice(id: noticeCounter, kind: kind))
    }

    /// The screen writes a saved file itself (the panel is its); what it could not write is said like every other refusal.
    public func fileNotWritten() {
        say(.fileNotWritten)
    }

    /// The screen reads chosen files itself; the ones it could not read are said like every other refusal.
    public func filesNotRead(_ names: [String]) {
        guard !names.isEmpty else { return }
        say(.filesNotRead(names))
    }

    public func dismiss(_ notice: Notice) {
        notices.removeAll { $0.id == notice.id }
    }

    // MARK: Starting

    /// At launch: the app's server, where a session kept from the last run is picked up again.
    public func launch() async {
        if let sessionOwner {
            await sessionOwner.launch()
            return
        }
        guard phase == .launching else { return }
        guard !launched else { return }
        launched = true
        phase = .launching
        await connect()
    }

    /// Asks the app's server what it is, and goes on to sign-in or to the person's workspace if a session is kept.
    public func connect() async {
        if let sessionOwner {
            await sessionOwner.connect()
            return
        }
        let address: ServerAddress
        do {
            address = try ServerAddress.parse(environment.serverAddress, allowsLocalHTTP: environment.allowsLocalHTTP)
        } catch {
            phase = .problem(.unreachable)
            say(.invalidAddress(error))
            return
        }
        phase = .checking
        let handshake = HandshakeClient(
            transport: environment.transport, appVersion: environment.appVersion,
            platform: environment.identity.platform,
            allowsLocalHTTP: environment.allowsLocalHTTP,
            sleep: environment.sleep)
        let outcome: HandshakeOutcome
        do {
            outcome = try await handshake.perform(address)
        } catch {
            switch error {
            case .unreachable: phase = .problem(.unreachable)
            case .notAPurlayServer: phase = .problem(.notAPurlayServer)
            case .rateLimited(let after): phase = .problem(.rateLimited(retryAfter: after))
            }
            server = address
            return
        }
        server = address
        switch outcome {
        case .ready(let info, let canonical):
            serverInfo = info
            origin = canonical
            await resumeOrAskToSignIn(address)
        case .appTooOld(let minimum, let info):
            serverInfo = info
            phase = .problem(.appTooOld(minimum))
        case .serverTooOld(let contract, let info):
            serverInfo = info
            phase = .problem(.serverTooOld(contract: contract))
        case .unusableOrigin(let text, let info):
            serverInfo = info
            phase = .problem(.unusableOrigin(text))
        }
    }

    // MARK: The session

    private func makeManager(for address: ServerAddress) -> SessionManager {
        let client = environment.transport
        let version = environment.appVersion
        return SessionManager(
            store: environment.sessions, owner: environment.owner, log: environment.log,
            wipers: personalDataWipers() + environment.wipers,
            now: environment.clock,
            endSession: { [weak self] scope in
                guard let self else { return }
                try await self.endServerSession(scope, client: client, version: version, address: address)
            },
            onWipeFailure: { [weak self] _ in await self?.say(.dataNotWiped) })
    }

    /// What the engine itself keeps of the person under this environment, removed before what the app names: the drafts in
    /// its preferences, the outbox in its data (the sender stopped writing it first) and the Quick Look copies in its caches.
    /// Made from this model's environment, which the Mac scopes per workspace session.
    private func personalDataWipers() -> [any UserDataWiper] {
        [
            DraftsWiper(preferences: environment.preferences),
            FolderWiper(
                FileOutboxStore.directory(in: environment.dataDirectory),
                stopWriting: { [weak self] in await self?.stopSendingForWipe() }),
            FolderWiper(previewsDirectory),
        ]
    }

    private func holdSends() {
        sendsHeld = true
        engine?.stop()
    }

    /// The sign-out did not happen: what was held goes on as before.
    private func releaseSends() {
        sendsHeld = false
        engine?.start()
        for place in waitingSends.keys { settleWaitingSend(place) }
    }

    /// The person's data is being removed, so the session is ending: nothing more is sent (a send waiting for its files is
    /// let go, the engine stops) and nothing more is written to the outbox, before the outbox goes.
    private func stopSendingForWipe() {
        waitingSends = [:]
        engine?.forgetOutbox()
        engine?.stop()
    }

    private func endServerSession(
        _ scope: SignOutScope, client: any HTTPTransport, version: SemanticVersion, address: ServerAddress
    ) async throws {
        guard let api else { throw TransportError.noSession }
        switch scope {
        case .thisDevice: try await api.logout()
        case .everywhere: try await api.logoutEverywhere()
        }
    }

    private func resumeOrAskToSignIn(_ address: ServerAddress) async {
        let manager = makeManager(for: address)
        self.manager = manager
        // A browser sign-in whose first read was lost: read again with it, rather than look in a Keychain that does not have it.
        if let pending = unkeptCredential {
            guard pending.origin == origin?.description else {
                unkeptCredential = nil
                await endSession(holding: pending.cookie, on: address)
                return await resumeOrAskToSignIn(address)
            }
            await manager.adopt(pending, for: address)
            heldSession = pending
            observe(manager)
            await bootstrap()
            return
        }
        do {
            let state = try await manager.restore(for: address)
            if case .signedOut(.expired) = state { say(.sessionExpired) }
            if case .signedIn(let session, _) = state {
                heldSession = session
                // An erasure whose answer never came before the app was quit stays unconfirmed for its person only.
                if !erasureUnconfirmed { forgetUnconfirmedErasure() }
                observe(manager)
                await bootstrap()
                return
            }
        } catch {
            say(.storageProblem)
        }
        // No session to apply an unconfirmed erasure to: whoever signs in next starts clean.
        forgetUnconfirmedErasure()
        phase = .signedOut
    }

    /// Signs in through the system browser. Signed in (or signing in) already, it does nothing: a second session would be
    /// adopted without the first being ended. Signing in again while signed in is `reauthenticate()`. Another session of
    /// the app on this server already signed in (the Mac's workspaces) is joined instead, with no browser: one person per
    /// server (ADR 0011). The session a browser sign-in gets is kept in the Keychain only once `/api/me` says whose it is;
    /// somebody other than the person the server's other sessions hold is refused (`anotherPersonSignedIn`).
    public func signIn() async {
        if let sessionOwner {
            await sessionOwner.signIn()
            return
        }
        guard let server, let origin, let manager, phase != .ready, phase != .loading, phase != .signingIn else {
            return
        }
        // A new sign-in proves the account is there, or is a new account: no earlier unconfirmed erasure applies to it.
        forgetUnconfirmedErasure()
        if let joined = sharedServer?.sessionInUse() {
            await manager.adopt(joined.session, for: server)
            heldSession = joined.session
            warnedOfExpiry = false
            observe(manager)
            await bootstrap()
            return
        }
        phase = .signingIn
        // With no other session of the server to answer to (iOS), the session is kept at once, as it always was.
        let flow = signInFlow(keepingIn: sharedServer == nil ? environment.sessions : UnkeptSessions())
        do {
            let session = try await flow.signIn(to: server, origin: origin)
            await manager.adopt(session, for: server)
            heldSession = session
            if sharedServer != nil { unkeptCredential = session }
            signedInAt = environment.clock()
            warnedOfExpiry = false
            observe(manager)
            await bootstrap()
        } catch {
            phase = .signedOut
            if error != .cancelled { say(.signInFailed(error)) }
        }
    }

    /// The browser sign-in (PKCE, the system's authentication session), keeping the session it gets in `store`.
    private func signInFlow(keepingIn store: any SessionStore) -> NativeSignIn {
        NativeSignIn(
            transport: environment.transport, appVersion: environment.appVersion,
            platform: environment.identity.platform, authenticator: environment.authenticator,
            store: store, deviceName: environment.deviceName)
    }

    /// Whether erasing the account needs a sign-in again first: the server asks for one within `ERASURE_SIGN_IN_MINUTES`,
    /// less a minute here for the request to arrive, and a session restored at launch is of an unknown age. A screen goes
    /// straight to `reauthenticate()` rather than ask and be refused; the server still decides
    /// (`EraseAccountResult.reauthenticationRequired`).
    public var erasureNeedsReauthentication: Bool {
        if let sessionOwner { return sessionOwner.erasureNeedsReauthentication }
        guard let signedInAt else { return true }
        let allowed = TimeInterval(ContractConstants.erasureSignInMinutes * 60) - Self.erasureSignInMargin
        return environment.clock().timeIntervalSince(signedInAt) >= allowed
    }

    /// Signs the person in again through the browser, as `signIn` does, while they stay signed in: for erasing the account,
    /// which needs a recent sign-in. The same person carries on with everything here on the new session (nothing is removed,
    /// the socket opens again on it) and the old session is ended. Somebody else signed in by the browser changes nothing:
    /// their session is ended at once (`differentPerson`). One asked for meanwhile shares the answer of the one under way.
    public func reauthenticate() async -> ReauthenticationResult {
        if let sessionOwner { return await sessionOwner.reauthenticate() }
        if let reauthenticating { return await reauthenticating.value }
        let run = Task { await reauthenticateOnce() }
        reauthenticating = run
        defer { reauthenticating = nil }
        return await run.value
    }

    private func reauthenticateOnce() async -> ReauthenticationResult {
        guard phase == .ready, ending == nil, sharedServer?.isEnding() != true, let server, let origin, let manager,
            let me,
            let old = cookieCache
        else {
            return .notSignedIn
        }
        // Not kept until it is known to be this person's: the Keychain holds the session in use until then.
        let fresh: StoredSession
        do {
            fresh = try await signInFlow(keepingIn: UnkeptSessions()).signIn(to: server, origin: origin)
        } catch {
            return .failed(error)
        }
        let whose: MeResponse
        do {
            whose = try await api(holding: fresh.cookie, on: server).getMe()
        } catch {
            await endSession(holding: fresh.cookie, on: server)
            return .failed(Self.signInError(error))
        }
        // The browser was open for a while: the session here may have ended or been replaced meanwhile, or another session
        // of the server may be signing out, which would leave the new one in the Keychain after it.
        guard phase == .ready, ending == nil, sharedServer?.isEnding() != true, cookieCache == old else {
            await endSession(holding: fresh.cookie, on: server)
            return .notSignedIn
        }
        guard whose.user.id == me.user.id else {
            await endSession(holding: fresh.cookie, on: server)
            return .differentPerson
        }
        do {
            try environment.sessions.save(fresh, for: server)
        } catch {
            await endSession(holding: fresh.cookie, on: server)
            return .failed(.storage(error as? KeychainError ?? KeychainError(status: -1, operation: "write")))
        }
        await manager.adopt(fresh, for: server)
        heldSession = fresh
        signedInAt = environment.clock()
        warnedOfExpiry = false
        // The socket moves to the new session before the old one ends, so the old one's ending is not heard here; so does
        // every other session that holds the old one.
        engine?.reconnect()
        await sharedServer?.renew(old, fresh)
        await endSession(holding: old, on: server)
        return .done
    }

    /// Another session of this server signed in again: this one, if it holds the session that is replaced (the same session
    /// is the same person, whether or not it has read who), moves to the new one before the old one is ended. A ready one
    /// opens its socket again on it; one still reading, or stopped by a problem, reads again with it.
    func adoptRenewedSession(_ session: StoredSession, replacing old: String) async {
        guard heldSession?.cookie == old, let server, let manager else { return }
        await manager.adopt(session, for: server)
        heldSession = session
        signedInAt = environment.clock()
        switch phase {
        case .ready: engine?.reconnect()
        case .loading, .problem:
            // What the old session was reading is not waited for: it is refused, and that refusal is not this one's.
            contextGeneration += 1
            Task { await bootstrap() }
        case .launching, .checking, .signedOut, .signingIn: break
        }
    }

    /// Keeps a browser sign-in's session in the Keychain now that `/api/me` says whose it is. Somebody other than the person
    /// the server's other sessions hold is refused, and a session that cannot be kept is not used: either way that session
    /// is ended at once, nothing is written or removed here, and the person is told why. True when it is kept.
    private func keep(
        _ session: StoredSession, for me: MeResponse, on server: ServerAddress, manager: SessionManager
    ) async -> Bool {
        let refusal: SignInError
        if let other = sharedServer?.sessionInUse()?.person, other != me.user.id.value {
            refusal = .anotherPersonSignedIn(server: server.origin.host() ?? server.description)
        } else {
            do {
                try environment.sessions.save(session, for: server)
                return true
            } catch {
                refusal = .storage(error as? KeychainError ?? KeychainError(status: -1, operation: "write"))
            }
        }
        // Not this app's session after all: its ending is not the server's to say, and nothing of anybody's is removed.
        observation?.cancel()
        observation = nil
        await manager.forgetUnkeptSession()
        tearDown()
        phase = .signedOut
        say(.signInFailed(refusal))
        await endSession(holding: session.cookie, on: server)
        return false
    }

    /// A client of `server` that sends `session`, whatever the session in use is: for a session this app is not using.
    private func api(holding session: String, on server: ServerAddress) -> PurlayAPI {
        PurlayAPI(
            client: APIClient(
                configuration: APIConfiguration(
                    baseURL: server.origin,
                    clientHeader: ClientHeader.value(
                        appVersion: environment.appVersion, platform: environment.identity.platform),
                    sessionCookie: { session }),
                transport: environment.transport, sleep: environment.sleep))
    }

    /// Ends a session this app is not using (`/auth/logout` with it). One the server could not be told of lives until it
    /// expires or is ended from the person's sessions list: logged, since nothing here depends on it.
    private func endSession(holding session: String, on server: ServerAddress) async {
        do {
            try await api(holding: session, on: server).logout()
        } catch {
            environment.log.session.error(
                "a session left by signing in again could not be ended: \(String(describing: type(of: error)), privacy: .public)"
            )
        }
    }

    /// What a failure to read whose a new session is says, in the words of a sign-in that failed.
    private static func signInError(_ error: any Error) -> SignInError {
        if let error = error as? TransportError { return .unreachable(error) }
        if let error = error as? APIError {
            if error.status == 429 { return .rateLimited(retryAfter: error.retryAfter) }
            return .refused(status: error.status, code: error.code)
        }
        return .noSessionInAnswer
    }

    /// Where a sign-in again leaves its session until it is known to be this person's: nowhere.
    private struct UnkeptSessions: SessionStore {
        func load(for server: ServerAddress) throws -> StoredSession? { nil }
        func save(_ session: StoredSession, for server: ServerAddress) throws {}
        func delete(for server: ServerAddress) throws {}
    }

    private func observe(_ manager: SessionManager) {
        observation?.cancel()
        observation = Task { @MainActor [weak self] in
            for await state in await manager.states() {
                guard let self, !Task.isCancelled else { return }
                guard case .signedOut(let reason) = state, phase == .ready || phase == .loading, ending == nil else {
                    continue
                }
                if erasureUnconfirmed && reason == .endedByServer {
                    await endAsErased(.accountPossiblyErased, answering: .possiblyErased)
                } else {
                    sessionEnded(reason)
                }
            }
        }
    }

    /// `announce`: false when the caller's own result says it, so the person is not told twice.
    private func sessionEnded(_ reason: SessionManager.Reason?, announce: Bool = true) {
        tearDown()
        phase = .signedOut
        switch reason {
        case .expired where announce: say(.sessionExpired)
        case .endedByServer where announce: say(.sessionEndedByServer)
        case .expired, .endedByServer, .signedOutByPerson, .signedOutEverywhere, .accountErased, nil: break
        }
        onSessionEnded?(nil)
    }

    /// The socket's `SESSION_ENDED`. Only an erasure (`account-deleted`) removes what the person kept here: their account is
    /// gone, and the sign-in the data would wait for cannot come (a returning person is given a new account). Every other
    /// reason ends the session as the server's, and keeps it.
    private func socketEndedSession(_ reason: SessionEndedFrame.Payload.Reason, manager: SessionManager) {
        guard reason == .accountDeleted else {
            // A reason only a live session is given (`signed-out`, `expired`): the account was still there, so an
            // unconfirmed erasure did not happen by then, and this is a session the server ended, said as one.
            if reason == .signedOut || reason == .expired { forgetUnconfirmedErasure() }
            Task { await manager.sessionEndedByServer() }
            return
        }
        switch ending {
        case .erasing:
            // This app's own erasure, or one already being said: the request says it, as `.erased`, when it ends.
            erasedBySocket = true
            Task { await manager.sessionEndedByServer() }
        case .signingOut(let run):
            // The sign-out removes everything; one that left the person signed in is ended here after it.
            Task {
                _ = await run.value
                await self.endAsErased(.accountErased, answering: .erased)
            }
        case nil:
            Task { await self.endAsErased(.accountErased, answering: .erased) }
        }
    }

    /// Ends a signed-in session as an erasure the server said (the socket, or a session ended after an unconfirmed one),
    /// holding the ending slot: an erasure asked meanwhile is answered `answer`, and a sign-out waits.
    private func endAsErased(_ notice: Notice.Kind, answering answer: EraseAccountResult) async {
        guard ending == nil, phase == .ready || phase == .loading else { return }
        let run = Task {
            await endErased(notice)
            return answer
        }
        ending = .erasing(run)
        _ = await run.value
        ending = nil
    }

    /// The account is gone, or very likely gone: this app signs out as a sign-out does, every wiper run once, and says so.
    private func endErased(_ notice: Notice.Kind) async {
        let person = me?.user.id.value ?? environment.owner.load()
        await manager?.accountErased()
        forgetUnconfirmedErasure()
        tearDown()
        phase = .signedOut
        say(notice)
        onSessionEnded?(person)
    }

    /// How many messages the person sent that the server has not yet been heard to have: the outbox, which signing out
    /// removes. The sign-out screen says it first, so nothing unsent goes without the person knowing.
    public var unsentMessageCount: Int {
        if let sessionOwner { return sessionOwner.unsentMessageCount }
        return pending.count { $0.delivery != .sent }
    }

    /// Where this session's Quick Look copies of attachments are kept, under its environment's caches: removed with the rest
    /// of what the person kept here.
    public var previewsDirectory: URL {
        environment.cacheDirectory.appendingPathComponent("Previews", isDirectory: true)
    }

    /// Ends the session here, or everywhere. The result says whether the server was told. Asked while an erasure is under way,
    /// it waits for it, and asks the server only if the person is still signed in after it.
    @discardableResult
    public func signOut(_ scope: SignOutScope) async -> SessionManager.SignOutResult {
        if let sessionOwner { return await sessionOwner.signOut(scope) }
        switch ending {
        case .signingOut(let run): return await run.value
        case .erasing(let run):
            _ = await run.value
            guard phase == .ready || phase == .loading else { return .done }
            return await signOut(scope)
        case nil: break
        }
        let run = Task { await signOutOnce(scope) }
        ending = .signingOut(run)
        defer { ending = nil }
        return await run.value
    }

    private func signOutOnce(_ scope: SignOutScope) async -> SessionManager.SignOutResult {
        guard let manager else { return .done }
        let person = me?.user.id.value ?? environment.owner.load()
        // From the moment the person asks: nothing more is sent while the server is told and the data removed.
        holdSends()
        let result = await manager.signOut(scope)
        switch result {
        case .done: break
        case .serverNotTold: say(.serverNotTold)
        case .notDone: say(.signOutEverywhereFailed)
        case .credentialKept: say(.signOutFailed)
        }
        switch result {
        case .notDone, .credentialKept:
            releaseSends()
            return result
        case .done, .serverNotTold: break
        }
        forgetUnconfirmedErasure()
        tearDown()
        phase = .signedOut
        onSessionEnded?(person)
        return result
    }

    /// Erases the person's account (`POST /api/me/erase`): `confirmation` is their username, typed, and one that is not is
    /// refused here without asking the server. On `erased` (or `possiblyErased`) this app signs out as a sign-out does, every
    /// wiper run once, and says so; every other answer is the screen's to act on (sign in again and retry, hand a workspace
    /// over) and changes nothing here, unless the session ended meanwhile. One asked for while one is under way waits for it
    /// and shares its answer, so the server is asked once: its own confirmation is not looked at, since the one screen that
    /// asks sends the same. One asked for while a sign-out is under way does not ask the server: the session is ending.
    public func eraseAccount(confirmation: String) async -> EraseAccountResult {
        if let sessionOwner { return await sessionOwner.eraseAccount(confirmation: confirmation) }
        switch ending {
        case .erasing(let run): return await run.value
        case .signingOut(let run):
            switch await run.value {
            case .done, .serverNotTold: return .sessionEnded
            case .notDone, .credentialKept: return .failed
            }
        case nil: break
        }
        let run = Task { await eraseAccountOnce(confirmation: confirmation) }
        ending = .erasing(run)
        defer { ending = nil }
        return await run.value
    }

    private func eraseAccountOnce(confirmation: String) async -> EraseAccountResult {
        // Signed out, there is nothing to erase; not yet signed in (launching, loading), asking again later is safe.
        guard phase == .ready, let api, let manager, let me else {
            return phase == .signedOut ? .sessionEnded : .failed
        }
        // The server compares with JavaScript's `!==`, code unit by code unit, where Swift's `==` would call two spellings of
        // the same letter equal: what the server would refuse is refused here without a request.
        guard confirmation.utf8.elementsEqual(me.user.username.utf8) else { return .confirmationMismatch }
        erasedBySocket = false
        var result: EraseAccountResult
        do {
            try await api.eraseMyAccount(body: EraseAccountRequest(confirm: confirmation))
            result = .erased
        } catch {
            result = EraseAccountResult(error)
        }
        if erasedBySocket { result = .erased }
        switch result {
        case .erased:
            await endErased(.accountErased)
            return .erased
        case .unconfirmed: markErasureUnconfirmed()
        // The server read the account and refused: it is still there.
        case .reauthenticationRequired, .lastOwner, .confirmationMismatch, .refused: forgetUnconfirmedErasure()
        case .failed, .sessionEnded, .possiblyErased: break
        }
        // A session that ended while the request was out (a `401`, or the socket) was left to this: ended now, as the
        // observer would have, and said once, by the result.
        guard case .signedOut(let reason) = await manager.state, phase == .ready || phase == .loading else {
            return result
        }
        if erasureUnconfirmed {
            await endErased(.accountPossiblyErased)
            return .possiblyErased
        }
        sessionEnded(reason, announce: false)
        return .sessionEnded
    }

    /// Stops this workspace without revoking the shared server credential a second time. `removingData`: the person signed
    /// out, or was erased, through another workspace of the same server, so what this one kept of them goes too.
    func invalidateLocalSession(removingDataOf person: String? = nil) {
        // Only the same person's: a workspace of the server held by somebody else keeps what it kept.
        if let person, person == (me?.user.id.value ?? environment.owner.load()), let manager {
            engine?.forgetOutbox()
            Task { await manager.personLeft() }
        }
        observation?.cancel()
        observation = nil
        tearDown()
        phase = .signedOut
    }

    // MARK: Signed in

    func bootstrap() async {
        guard let server, let origin, let manager else { return }
        phase = .loading
        chatRouteUnavailable = false
        let context = contextGeneration
        let client = APIClient(
            configuration: APIConfiguration(
                baseURL: server.origin,
                clientHeader: ClientHeader.value(
                    appVersion: environment.appVersion, platform: environment.identity.platform),
                sessionCookie: { await manager.cookie },
                onSessionRejected: { await manager.sessionEndedByServer(rejecting: $0) },
                onProblem: { [weak self] problem in await self?.recordProblem(problem) }),
            transport: environment.transport, sleep: environment.sleep)
        let api = PurlayAPI(client: client)
        self.api = api
        do {
            let me = try await api.getMe()
            guard context == contextGeneration else { return }
            if let unkept = unkeptCredential {
                unkeptCredential = nil
                guard await keep(unkept, for: me, on: server, manager: manager) else { return }
            }
            self.me = me
            await manager.identify(userID: me.user.id.value)
            guard context == contextGeneration else { return }
            if me.mustEnrolTwoFactor {
                // Held back until two-step verification is on (D-239): every route but this one answers 403, so nothing
                // more is read. The window says why and where to turn it on, and reads this again when asked.
                workspace = nil
                phase = .ready
                return
            }
            // The one remembered from before, if the person is still in it; otherwise the last one used, otherwise the first.
            let membership =
                preferredWorkspaceID.flatMap { id in me.memberships.first { $0.workspace.id == id } }
                ?? me.memberships.first { $0.workspace.slug == environment.preferences.string(for: "workspace") }
                ?? me.memberships.first
            guard let membership else {
                // Signed in, in no workspace: nothing to show here yet.
                workspace = nil
                phase = .ready
                return
            }
            workspace = membership.workspace
            loadSidebarLayout()
            environment.preferences.set(membership.workspace.slug, for: "workspace")
            guard chatAvailable else {
                phase = .ready
                return
            }
            let channels: ChannelList
            do {
                channels = try await api.listChannels(workspaceId: membership.workspace.id.value)
            } catch let error as APIError where error.status == 404 && error.code.rawValue == "ROUTE_NOT_FOUND" {
                guard context == contextGeneration else { return }
                // During a rollout, the node serving channels can have a different module set from /api/me.
                chatRouteUnavailable = true
                phase = .ready
                return
            }
            guard context == contextGeneration else { return }
            let engine = makeEngine(me: me, client: client, api: api, origin: origin, manager: manager)
            self.engine = engine
            let load = engine.restore()
            if load.unrestorable > 0 { say(.unrestorable(load.unrestorable)) }
            if load.corruptFile != nil { say(.outboxCorrupt) }
            // Prime the unread baseline before publishing the channel list.
            attention.prime(channels)
            engine.setChannels(channels)
            watchJoined()
            await loadChannelGroups()
            engine.start()
            sync()
            await refreshPeople()
            guard context == contextGeneration else { return }
            noteActivity()
            reread(.presence(workspace: membership.workspace.id)) { await $0.loadPresence() }
            reread(.reminders(workspace: membership.workspace.id)) { await $0.loadReminders() }
            reread(.saved(workspace: membership.workspace.id)) { await $0.reloadSaved() }
            let remembered = environment.preferences.string(for: "channel.\(membership.workspace.slug)").flatMap(
                Uuid.init)
            let first =
                channels.first { $0.id == remembered && $0.state != nil }
                ?? Sidebar.sections(channels).first?.channels.first
            phase = .ready
            guard context == contextGeneration else { return }
            if let first { await open(first.id) }
        } catch let error as APIError where error.status == 401 {
            // Told by the session manager already.
        } catch {
            guard context == contextGeneration else { return }
            if (error as? TransportError)?.isTransient == true {
                phase = .problem(.unreachable)
            } else {
                phase = .problem(.notAPurlayServer)
            }
        }
    }

    private func makeEngine(
        me: MeResponse, client: APIClient, api: PurlayAPI, origin: ServerAddress, manager: SessionManager
    ) -> Engine {
        let outbox: any OutboxStore =
            FileOutboxStore(base: environment.dataDirectory, userID: me.user.id.value, now: environment.clock)
            ?? EmptyOutbox()
        let serverClock = ServerClock(local: environment.clock)
        let session = manager
        let socketURL = URLSessionSocketTransport.socketURL(for: origin.origin) ?? origin.origin
        let opener = environment.openSocket
        return Engine(
            .init(
                url: socketURL,
                openSocket: { [weak self] url, handlers in
                    // The session is read when a socket is opened: it may have changed since the engine was made.
                    try opener(origin, self?.currentCookie() ?? "")(url, handlers)
                },
                schedule: environment.schedule, random: environment.random, clock: environment.clock,
                serverClock: serverClock, log: environment.log,
                checkSession: {
                    do {
                        _ = try await api.getMe()
                        return .active
                    } catch let error as APIError where error.status == 401 {
                        return .ended
                    } catch {
                        return .unknown
                    }
                },
                selfID: me.user.id, outbox: outbox,
                sendHTTP: { channel, body in try await api.sendMessage(channelId: channel.value, body: body) },
                readAfter: { channel, after in
                    try await api.listMessages(channelId: channel.value, query: PageQuery(after: after))
                },
                refresh: { [weak self] refresh in self?.handle(refresh) },
                onSessionEnded: { [weak self] reason in self?.socketEndedSession(reason, manager: session) },
                onRefused: { [weak self] status in self?.upgradeRefused(status) },
                onLost: { [weak self] count in self?.say(.unsentLost(count)) },
                onStorageProblem: { [weak self] _ in self?.say(.storageProblem) },
                onChange: { [weak self] in self?.sync() }, onReply: { [weak self] reply in self?.receiveReply(reply) }))
    }

    private struct EmptyOutbox: OutboxStore {
        func load() -> OutboxLoad { .empty }
        func save(_ messages: [StoredMessage]) throws {}
    }

    private var cookieCache: String? { heldSession?.cookie }

    private func currentCookie() -> String? { cookieCache }

    private func upgradeRefused(_ status: Int) {
        switch status {
        case 401:
            if let manager { Task { await manager.sessionEndedByServer() } }
        case 426:
            if let minimum = serverInfo?.minClient.macos {
                tearDown()
                phase = .problem(.appTooOld(minimum))
            }
        default:
            say(.originMismatch)
        }
    }

    private func tearDown() {
        if let dropped = unkeptCredential, let server {
            // Never kept and now let go: ended, so it is not left alive on the server with nothing holding it.
            Task { await endSession(holding: dropped.cookie, on: server) }
        }
        heldSession = nil
        unkeptCredential = nil
        sendsHeld = false
        signedInAt = nil
        awayChange += 1
        for window in liveConversationWindows {
            // Only the session owner stops the connection and clears shared state.
            window.sessionOwner = nil
            window.engine = nil
            window.tearDown()
            window.phase = .signedOut
        }
        conversationWindows = []
        clearReminders()
        contextGeneration += 1
        markedRead = [:]
        marking = []
        closeThread()
        threadMarked = [:]
        knowledgeSaving = []
        readRetryAfter = [:]
        engine?.stop()
        engine = nil
        api = nil
        me = nil
        clearSearch()
        recentSearches = []
        clearSavedSearches()
        focus = nil
        editing = nil
        uploadsByPlace = [:]
        waitingSends = [:]
        handedBack = [:]
        keyboardRow = nil
        problems = ProblemLog()
        clearInbox()
        clearUnresolved()
        clearIssues()
        linkPreviews = [:]
        linkPreviewFailures = [:]
        uploadBytes = [:]
        attachmentCache = [:]
        attachmentCacheOrder = []
        attachmentCacheBytes = 0
        savedIDs = [:]
        deletionTarget = nil
        deletingMessages = []
        scheduledItems = []
        scheduledOpen = false
        // A sheet left open by the session that ended must not open by itself for the next.
        draftIndex.scanned = []
        draftIndex.drafted = []
        paletteOpen = false
        searchOpen = false
        pinsOpen = false
        savedOpen = false
        draftsOpen = false
        shortcutsOpen = false
        threadLoadFailed = false
        channelLoadFailed = []
        scheduledGeneration += 1
        scheduledLoading = false
        scheduledFailed = false
        savedItems = []
        savedGeneration &+= 1
        savedStatus = .idle
        savedCursor = nil
        loadingMoreSaved = false
        savedPaginationFailed = false
        savedUpdating = []
        savedState = .inProgress
        pins = [:]
        bookmarks = [:]
        addingBookmark = nil
        unreadHold = nil
        // After the engine is gone: stopping it says it changed, and that would count what is no longer anybody's.
        attention = Attention()
        deepWorkTimer?()
        deepWorkTimer = nil
        for cancel in refreshRetry.values { cancel() }
        refreshRetry = [:]
        if lastBadge != nil { environment.attention.setBadge(nil) }
        lastBadge = nil
        workspacePeople = []
        channelPeople = [:]
        settingsPage = .general
        workspace = nil
        sidebarLayout = SidebarLayout()
        selectedChannel = nil
        chat = ChatState()
        pending = []
        connection = .idle
        degraded = [:]
    }

    func sync() {
        guard let engine else { return }
        chat = engine.chat
        pending = engine.pending
        let wasOpen = connection == .open
        connection = engine.status
        // Connected while the person is in front of the app: they are here, and a server that restarted has to be told.
        if !wasOpen, connection == .open { noteActivity() }
        degraded = engine.degraded
        markReadIfSeen()
        if sessionOwner == nil {
            tellAttention()
            for window in liveConversationWindows { window.sync() }
        }
    }

    // MARK: Reading

    /// The window is, or is not, the one in front of the person.
    public func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        readRetryAfter = [:]
        markReadIfSeen()
        markThreadReadIfSeen()
        (sessionOwner ?? self).tellAttention()
        // Coming to the front is an act of the person's own (D-143).
        noteActivity()
        if active { Task { await checkSession() } }
    }

    /// A session that ended while the app was away is found now, not at the next refused request, and one about to end is said.
    func checkSession() async {
        if let sessionOwner {
            await sessionOwner.checkSession()
            return
        }
        guard phase == .ready, let manager else { return }
        await manager.checkExpiry()
        guard phase == .ready, !warnedOfExpiry, let end = await manager.expiresAt,
            end.timeIntervalSince(environment.clock()) < Self.sessionWarning
        else { return }
        warnedOfExpiry = true
        say(.sessionEndsSoon(end))
    }

    /// The person is at the end of the messages, or has scrolled up.
    public func setAtBottom(_ bottom: Bool) {
        guard bottom != atBottom else { return }
        atBottom = bottom
        readRetryAfter = [:]
        markReadIfSeen()
    }

    /// Marks the open channel read up to its newest message when the person can see it: the app is in front, the newest message is in
    /// view, and the window reaches the present. Nothing is marked read from a window short of the present, and a message already read
    /// is not marked again.
    private func markReadIfSeen() {
        guard isActive, atBottom, !inboxOpen, !unresolvedOpen, let channel = selectedChannel, unreadHold != channel,
            let window = chat.windows[channel],
            window.reachesNewest,
            let newest = window.messages.last?.id, let api, engine != nil, !marking.contains(channel),
            (readRetryAfter[channel] ?? .distantPast) <= environment.clock()
        else { return }
        let read = [markedRead[channel], chat.channels[channel]?.state?.lastReadMessageId].compactMap { $0 }.max()
        if let read, read >= newest { return }
        marking.insert(channel)
        let context = contextGeneration
        Task { @MainActor in
            defer { if context == contextGeneration { marking.remove(channel) } }
            do {
                let state = try await api.markChannelRead(
                    channelId: channel.value, body: ReadChannelRequest(lastReadMessageId: newest))
                guard context == contextGeneration else { return }
                markedRead[channel] = newest
                engine?.setState(state, for: channel)
                sync()
            } catch {
                guard context == contextGeneration else { return }
                // Not read yet, and nothing said: it is asked again when the person next sees the channel, or after a while.
                readRetryAfter[channel] = environment.clock().addingTimeInterval(Self.readRetryDelay)
            }
        }
    }

    /// The read position of a channel moved back: what any window marked read is forgotten, so the next look reads it again.
    func forgetRead(_ channel: Uuid) {
        let owner = sessionOwner ?? self
        for model in [owner] + owner.liveConversationWindows {
            model.markedRead[channel] = nil
            model.readRetryAfter[channel] = nil
        }
    }

    // MARK: What is held

    /// How much of the person's the model holds, by kind: what "Memory after sign-out" (§14) can count. A new collection that is not
    /// added here is one a test cannot see leak, so a collection is added here when it is made.
    var retainedParts: [(String, Int)] {
        [
            ("notices", notices.count), ("pending", pending.count), ("degraded", degraded.count),
            ("markedRead", markedRead.count), ("readRetryAfter", readRetryAfter.count),
            ("workspacePeople", workspacePeople.count), ("channelPeople", channelPeople.count),
            ("threadMarked", threadMarked.count), ("knowledgeSaving", knowledgeSaving.count),
            ("thread", thread == nil ? 0 : 1), ("inboxRows", inboxRows.count),
            ("inboxNotes", inboxNotes.count), ("savedIDs", savedIDs.count), ("savedItems", savedItems.count),
            ("pins", pins.count), ("bookmarks", bookmarks.count), ("unreadHold", unreadHold == nil ? 0 : 1),
            ("uploads", uploadsByPlace.count), ("uploadBytes", uploadBytes.count),
            ("attachmentCache", attachmentCache.count + attachmentCacheOrder.count + attachmentCacheBytes),
            ("waitingSends", waitingSends.count), ("handedBack", handedBack.count),
            ("searchResults", searchResults.count), ("problems", problems.entries.count),
            ("channels", chat.channels.count), ("windows", chat.windows.count), ("gone", chat.gone.count),
            ("typing", chat.typing.count), ("presence", chat.presence.count), ("deepWork", chat.deepWork.count),
            ("selectedChannel", selectedChannel == nil ? 0 : 1), ("me", me == nil ? 0 : 1),
            ("workspace", workspace == nil ? 0 : 1), ("keyboardRow", keyboardRow == nil ? 0 : 1),
            ("focus", focus == nil ? 0 : 1), ("editing", editing == nil ? 0 : 1),
            ("refreshRetry", refreshRetry.count), ("sidebarGroups", sidebarLayout.groups.count),
        ]
    }

    var retainedItemCount: Int { retainedParts.reduce(0) { $0 + $1.1 } }

    /// What is held, for a failing test to say.
    var retainedDescription: String {
        retainedParts.filter { $0.1 > 0 }.map { "\($0.0)=\($0.1)" }.joined(separator: " ")
    }

    // MARK: Opening at login

    /// What the system holds, not what was asked of it.
    public private(set) var launchAtLogin: LoginItemStatus = .unavailable

    public func refreshLoginItem() {
        launchAtLogin = environment.loginItem.status
    }

    public func setLaunchAtLogin(_ on: Bool) {
        do {
            try environment.loginItem.set(on)
        } catch {
            say(.loginItemFailed)
        }
        refreshLoginItem()
    }

    public func openLoginItemSettings() {
        environment.loginItem.openSystemSettings()
    }

    // MARK: Diagnostics

    @ObservationIgnored private var problems = ProblemLog()

    fileprivate func recordProblem(_ problem: ProblemRecord) {
        problems.record(problem)
    }

    /// What "Copy diagnostics" puts on the pasteboard: versions, the connection and the last problems by code. No content, no address.
    public func diagnostics(system: String) -> String {
        Diagnostics.report(
            appVersion: "\(environment.appVersion)", system: system, serverVersion: serverInfo?.server.version,
            contractVersion: serverInfo?.contractVersion, connection: Self.describe(connection),
            problems: problems.entries)
    }

    private static func describe(_ status: Connection.Status) -> String {
        switch status {
        case .idle: return "idle"
        case .connecting: return "connecting"
        case .open: return "open"
        case .waiting: return "waiting"
        case .ended: return "ended"
        }
    }

}

@MainActor
private final class WeakConversationModel {
    weak var model: AppModel?
    init(_ model: AppModel) { self.model = model }
}

extension AppModel {
    var liveConversationWindows: [AppModel] {
        conversationWindows.removeAll { $0.model == nil }
        return conversationWindows.compactMap(\.model)
    }

    var sessionIsActive: Bool { isActive || liveConversationWindows.contains { $0.isActive } }

    public func conversationWindowRequest(for channel: Uuid) -> ConversationWindowRequest? {
        guard let origin, let me, let workspace, chat.channels[channel] != nil else { return nil }
        return ConversationWindowRequest(
            server: origin.description, user: me.user.id, workspace: workspace.id, channel: channel)
    }

    /// Each window owns navigation and presentation; one session owns the socket, outbox and account data.
    public func makeConversationWindow(_ request: ConversationWindowRequest) async -> AppModel? {
        if let sessionOwner { return await sessionOwner.makeConversationWindow(request) }
        guard phase == .ready, request.server == origin?.description, request.user == me?.user.id,
            request.workspace == workspace?.id, chat.channels[request.channel] != nil
        else { return nil }
        var windowEnvironment = environment
        windowEnvironment.attention = SilentAttention()
        let window = AppModel(windowEnvironment)
        window.sessionOwner = self
        window.phase = .ready
        window.server = server
        window.origin = origin
        window.serverInfo = serverInfo
        window.workspace = workspace
        window.engine = engine
        window.api = api
        window.draftRevision = draftRevision
        window.isActive = false
        conversationWindows.append(WeakConversationModel(window))
        window.sync()
        await window.showChannel(request.channel)
        guard window.phase == .ready else { return nil }
        return window
    }

    public func closeConversationWindow() {
        guard let owner = sessionOwner else { return }
        owner.conversationWindows.removeAll { $0.model === self }
        sessionOwner = nil
        engine = nil
        tearDown()
        phase = .signedOut
    }
}

extension Channel {
    /// A channel's name, or the people in a conversation, by name.
    public var title: String {
        if let name { return name }
        return peers.map(\.displayName).sorted().joined(separator: ", ")
    }
}

#if DEBUG
extension AppModel {
    /// For drawing a screen from state in a test: puts in place what a signed-in window would hold, without a server. A debug seam
    /// only, and in this file so that what is private to the model stays private to it: a release build has no way to set it.
    func adoptForDrawing(chat: ChatState, workspace: Workspace?) {
        self.chat = chat
        self.workspace = workspace
    }
}
#endif

/// What the other sessions of this app on one server share with a session (the Mac's workspaces of that server): one
/// credential in the Keychain and one person (ADR 0011). `DesktopSessions` makes one for each of its models.
@MainActor
struct SharedServer {
    /// The session another signed-in session of the server holds, and whose it is when known: a sign-in joins it instead of
    /// opening the browser, and a browser sign-in of anybody else is refused.
    var sessionInUse: () -> (session: StoredSession, person: String?)?
    /// Another session of the server is ending (a sign-out, an erasure): a sign-in again does not put a session back.
    var isEnding: () -> Bool
    /// Every other session of the server that holds `old` moves to `fresh`.
    var renew: (_ old: String, _ fresh: StoredSession) async -> Void
}
