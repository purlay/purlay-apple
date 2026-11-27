import FeatureChat
import PurlayContract
import PurlayKit
import PurlayModuleAPI
import PurlayWords
import SwiftUI

/// The signed-in shell borrows the Kit's authority and owns the presentation of destinations this build ships.
@MainActor
enum WorkspaceDestinations {
    static func features(for model: AppModel) -> [any FeatureModule] {
        guard let workspace = model.workspace else { return [] }
        let registry = ModuleRegistry([
            ChatFeature(model: model, workspace: workspace.id, title: Words.chat, words: Words.chatStrings)
        ])
        let allowed: Set<ModuleID> = ChatFeature.isAvailable(model: model, workspace: workspace.id) ? [.chat] : []
        return registry.enabled(allowed: allowed)
    }
}

struct WorkspaceShell: View {
    @Environment(\.horizontalSizeClass) private var width
    @State private var selected: ModuleID?
    @State private var confirmSignOut = false
    /// A sign-out asked for while messages are unsent: it waits for the person to accept that they are deleted.
    @State private var signOutLosingUnsent: SignOutScope?
    @State private var columns = NavigationSplitViewVisibility.all
    let sessions: WorkspaceSessions

    var body: some View {
        let model = sessions.active
        let features = WorkspaceDestinations.features(for: model)
        Group {
            if features.isEmpty {
                empty(model)
            } else if width == .regular {
                sidebar(features)
            } else {
                tabs(features)
            }
        }
        .onChange(of: features.map(\.id), initial: true) { _, ids in
            if selected.map(ids.contains) != true { selected = ids.first }
        }
        .alert(Text(SharedWords.signOutEverywhere), isPresented: $confirmSignOut) {
            Button(role: .destructive) {
                Task { await sessions.signOut(.everywhere) }
            } label: {
                Text(SharedWords.signOutEverywhere)
            }
            .accessibilityIdentifier("account.confirmSignOutEverywhere")
            Button(role: .cancel) {
            } label: {
                Text(SharedWords.cancel)
            }
        } message: {
            Text(Words.signOutEverywhereDetail)
        }
        // Interim, until the Account sheet's design session: signing out deletes what is unsent (the engine's wipe), so the
        // person is told how many first.
        .confirmationDialog(
            Text(Words.unsentWillBeDeleted(sessions.active.unsentMessageCount)),
            isPresented: Binding(get: { signOutLosingUnsent != nil }, set: { if !$0 { signOutLosingUnsent = nil } }),
            titleVisibility: .visible, presenting: signOutLosingUnsent
        ) { scope in
            Button(role: .destructive) {
                Task { await sessions.signOut(scope) }
            } label: {
                Text(scope == .everywhere ? SharedWords.signOutEverywhere : Words.signOutThisDevice)
            }
            .accessibilityIdentifier("account.confirmSignOutLosingUnsent")
            Button(role: .cancel) {
            } label: {
                Text(SharedWords.cancel)
            }
        } message: { scope in
            if scope == .everywhere { Text(Words.signOutEverywhereDetail) }
        }
    }

    /// A sign-out with nothing unsent goes at once (everywhere asks first); one with unsent messages asks before deleting them.
    private func requestSignOut(_ scope: SignOutScope) {
        if WorkspaceShell.asksBeforeSigningOut(unsent: sessions.active.unsentMessageCount) {
            signOutLosingUnsent = scope
        } else if scope == .everywhere {
            confirmSignOut = true
        } else {
            Task { await sessions.signOut(.thisDevice) }
        }
    }

    /// Whether a sign-out must first say that unsent messages will be deleted.
    nonisolated static func asksBeforeSigningOut(unsent: Int) -> Bool { unsent > 0 }

    private func tabs(_ features: [any FeatureModule]) -> some View {
        TabView(selection: $selected) {
            ForEach(features, id: \.id) { feature in
                Tab(value: Optional(feature.id)) {
                    NavigationStack {
                        feature.makeRoot()
                            .navigationTitle(Text(feature.title))
                            .toolbar { toolbar }
                    }
                    .id(ObjectIdentifier(sessions.active))
                } label: {
                    featureLabel(feature)
                }
            }
        }
    }

    private func sidebar(_ features: [any FeatureModule]) -> some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selected) {
                ForEach(features, id: \.id) { feature in
                    NavigationLink(value: feature.id) { featureLabel(feature) }
                        .accessibilityIdentifier("workspace.sidebar.\(feature.id.rawValue)")
                }
            }
            .listStyle(.sidebar)
            .toolbar { toolbar }
        } detail: {
            if let feature = features.first(where: { $0.id == selected }) ?? features.first {
                NavigationStack {
                    feature.makeRoot()
                        .navigationTitle(Text(feature.title))
                }
                .id(ObjectIdentifier(sessions.active))
            }
        }
    }

    /// With no destination to show, what stands in its place is the screen `RootScreen` decides for the account: two-step
    /// verification to set up, no workspace at all, or a workspace whose server runs no module this build draws.
    private func empty(_ model: AppModel) -> some View {
        NavigationStack {
            Group {
                switch RootScreen(model) {
                case .twoFactorRequired:
                    ContentUnavailableView {
                        Label {
                            Text(Words.twoFactorRequired)
                        } icon: {
                            Image(systemName: "lock.shield")
                        }
                    } actions: {
                        if let destination = model.twoFactorSetupURL {
                            Link(destination: destination) { Text(Words.setUpTwoFactor) }
                        }
                        // After setting it up in the browser, the account is read again.
                        Button {
                            Task { await RootActions.refreshAccount(model) }
                        } label: {
                            Text(SharedWords.refresh)
                        }
                        .accessibilityIdentifier("workspace.refreshAccount")
                    }
                case .noWorkspace:
                    ContentUnavailableView {
                        Label {
                            Text(Words.noWorkspaces)
                        } icon: {
                            Image(systemName: "person.2")
                        }
                    } actions: {
                        // After an invitation is accepted, only a new connection finds the workspace.
                        Button {
                            Task { await RootActions.reload(model) }
                        } label: {
                            Text(SharedWords.refresh)
                        }
                        .accessibilityIdentifier("workspace.reload")
                    }
                    .accessibilityIdentifier("workspace.emptyMemberships")
                    .navigationTitle(Text(SharedWords.workspace))
                case .busy, .problem, .signIn, .ready:
                    ContentUnavailableView {
                        Label {
                            Text(Words.noWorkspaceModules)
                        } icon: {
                            Image(systemName: "square.grid.2x2")
                        }
                    }
                    .accessibilityIdentifier("workspace.emptyModules")
                    .navigationTitle(Text(SharedWords.workspace))
                }
            }
            .toolbar { toolbar }
        }
    }

    private func featureLabel(_ feature: any FeatureModule) -> some View {
        Label {
            Text(feature.title)
        } icon: {
            Image(systemName: feature.systemImage)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let workspace = sessions.active.workspace {
                WorkspaceSwitcher(sessions: sessions, workspace: workspace)
            }
            if sessions.isSigningOut {
                ProgressView()
                    .accessibilityLabel(Text(Words.signingOut))
                    .accessibilityIdentifier("account.signingOut")
            } else {
                Menu {
                    Button(role: .destructive) {
                        requestSignOut(.thisDevice)
                    } label: {
                        Text(Words.signOutThisDevice)
                    }
                    .accessibilityIdentifier("account.signOutThisDevice")
                    Button(role: .destructive) {
                        requestSignOut(.everywhere)
                    } label: {
                        Text(SharedWords.signOutEverywhereMenu)
                    }
                    .accessibilityIdentifier("account.signOutEverywhere")
                } label: {
                    Label {
                        Text(Words.account)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                    .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("account.menu")
                .disabled(sessions.isChangingSession)
            }
        }
    }
}

private struct WorkspaceSwitcher: View {
    let sessions: WorkspaceSessions
    let workspace: Workspace

    var body: some View {
        let choices = sessions.choices
        if choices.count > 1 {
            Menu {
                ForEach(choices, id: \.id) { candidate in
                    Button {
                        Task { await sessions.select(candidate.id) }
                    } label: {
                        if candidate.id == workspace.id {
                            Label {
                                Text(verbatim: choiceLabel(candidate, in: choices))
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        } else {
                            Text(verbatim: choiceLabel(candidate, in: choices))
                        }
                    }
                    .accessibilityAddTraits(candidate.id == workspace.id ? .isSelected : [])
                }
            } label: {
                HStack {
                    Text(verbatim: workspace.name).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                }
            }
            .accessibilityLabel(Text(Words.switchWorkspace(choiceLabel(workspace, in: choices))))
            .accessibilityIdentifier("workspace.switcher")
            .disabled(sessions.isChangingSession)
        } else {
            Text(verbatim: workspace.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityIdentifier("workspace.name")
        }
    }

    /// A workspace's name, with its address beside it when another of the person's workspaces has the same name.
    private func choiceLabel(_ candidate: Workspace, in choices: [Workspace]) -> String {
        choices.contains { $0.id != candidate.id && $0.name == candidate.name }
            ? String(localized: Words.workspaceWithAddress(candidate.name, candidate.slug)) : candidate.name
    }
}
