import PurlayDesign
import PurlayKit
import PurlayWords
import SwiftUI

/// One screen per phase of the app's model, with what the model said to the person above it. Only system components: navigation
/// chrome and materials are the system's, and any OS-version branching would live in `PurlayDesign`, never here.
struct RootView: View {
    let sessions: WorkspaceSessions
    /// The mark the entry screens share, drawn once over them: it travels from the launch screen's place to Welcome and back.
    @Namespace private var brand

    private var model: AppModel { sessions.active }

    var body: some View {
        let screen = RootScreen(model)
        // The switch sits inside the animated container, so a screen that leaves animates as well as the one that arrives.
        ZStack { content(screen) }
            .entryMark(in: brand, shown: screen.showsMark)
            .purlayAnimation(.smooth, value: screen)
            .safeAreaInset(edge: .top, spacing: 0) { NoticeList(model: model) }
    }

    @ViewBuilder
    private func content(_ screen: RootScreen) -> some View {
        switch screen {
        case .busy(let busy): ConnectingView(busy: busy, brand: brand)
        case .problem(let problem):
            ProblemView(
                problem: problem, retry: { await RootActions.retry(model) },
                returnWorkspace: sessions.returnWorkspace?.name,
                returnToWorkspace: { await sessions.returnToPreviousWorkspace() })
        case .signIn:
            WelcomeView(server: model.server?.origin.host(), brand: brand, signIn: { await RootActions.signIn(model) })
        case .ready, .twoFactorRequired, .noWorkspace: WorkspaceShell(sessions: sessions)
        }
    }
}

/// The server cannot be used, and the one thing that can be done about it.
private struct ProblemView: View {
    let problem: ServerProblem
    let retry: () async -> Void
    let returnWorkspace: String?
    let returnToWorkspace: () async -> Void

    var body: some View {
        let words = EngineWords.problem(problem)
        Scrolling {
            ContentUnavailableView {
                Label(words.title, systemImage: "wifi.exclamationmark")
            } description: {
                Text(words.detail)
            } actions: {
                Button {
                    Task { await retry() }
                } label: {
                    Text(EngineWords.tryAgain)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if let returnWorkspace {
                    Button {
                        Task { await returnToWorkspace() }
                    } label: {
                        Text(Words.backToWorkspace(returnWorkspace))
                    }
                }
            }
        }
    }
}

/// What the model said that is not a screen of its own, each to be dismissed, on the glass the notices share. VoiceOver does not
/// read a banner that appears on its own, so each new one is announced, once.
struct NoticeList: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let model: AppModel

    /// The space above the notices. A landscape iPhone hides the status bar and leaves no top safe area, so the notices keep
    /// their own margin there instead of touching the screen's edge; elsewhere the status bar's area is the margin.
    nonisolated static func topMargin(_ verticalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        verticalSizeClass == .compact ? 8 : 0
    }

    var body: some View {
        PurlayNoticeStack {
            ForEach(model.notices) { notice in
                if let words = EngineWords.notice(notice.kind) {
                    NoticeBanner(words: words) { model.dismiss(notice) }
                        .purlayNoticeTransition()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, Self.topMargin(verticalSizeClass))
        .purlayAnimation(.smooth, value: model.notices)
        .onChange(of: model.notices) { old, new in
            let sentences = Self.arrivals(from: old, to: new).compactMap { EngineWords.notice($0.kind) }
            guard !sentences.isEmpty else { return }
            AccessibilityNotification.Announcement(sentences.map { String(localized: $0) }.joined(separator: "\n"))
                .post()
        }
    }

    /// The notices in `new` that were not in `old`, in the order they are shown: each is announced when it arrives, never again.
    nonisolated static func arrivals<Item: Identifiable>(from old: [Item], to new: [Item]) -> [Item] {
        let shown = Set(old.map(\.id))
        return new.filter { !shown.contains($0.id) }
    }
}
