import PurlayDesign
import PurlayKit
import SwiftUI

/// One screen per phase of the app's model, with what the model said to the person above it. Only system components: navigation
/// chrome and materials are the system's, and any OS-version branching would live in `PurlayDesign`, never here.
struct RootView: View {
    let model: AppModel
    /// The mark the entry screens share, drawn once over them: it travels from the launch screen's place to Welcome and back.
    @Namespace private var brand

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
        case .problem(let problem): ProblemView(problem: problem, retry: { await RootActions.retry(model) })
        case .signIn:
            WelcomeView(server: model.server?.origin.host(), brand: brand, signIn: { await RootActions.signIn(model) })
        case .ready, .twoFactorRequired, .noWorkspace:
            ContentUnavailableView {
                Label(Words.signedInTitle, systemImage: "checkmark.circle")
            } description: {
                Text(Words.signedInDetail)
            }
        }
    }
}

/// The server cannot be used, and the one thing that can be done about it.
private struct ProblemView: View {
    let problem: ServerProblem
    let retry: () async -> Void

    var body: some View {
        let words = Words.problem(problem)
        Scrolling {
            ContentUnavailableView {
                Label(words.title, systemImage: "wifi.exclamationmark")
            } description: {
                Text(words.detail)
            } actions: {
                Button {
                    Task { await retry() }
                } label: {
                    Text(Words.tryAgain)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

/// What the model said that is not a screen of its own, one line each, each to be dismissed.
private struct NoticeList: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(model.notices) { notice in
                if let words = Words.notice(notice.kind) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(words).font(.callout).padding(.vertical, 12).frame(
                            maxWidth: .infinity, alignment: .leading)
                        Button {
                            model.dismiss(notice)
                        } label: {
                            Image(systemName: "xmark")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .accessibilityLabel(Text(Words.dismiss))
                    }
                    .padding(.leading)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                    .padding(.horizontal)
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }
}
