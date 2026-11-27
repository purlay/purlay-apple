#if os(macOS)
import PurlayContract
import PurlayKit
import PurlayTokens
import SwiftUI

/// Where the account is signed in: this Mac first, then the most recently used, each other one with a way to sign it out.
/// This Mac is signed out with Sign Out, which also forgets what it keeps.
struct DeviceSessionsSection: View {
    let model: AppModel
    @State private var sessions: [DeviceSession]?
    @State private var failed = false
    @State private var ending: DeviceSession?
    @State private var endFailed = false

    var body: some View {
        Section("Signed In On") {
            if let sessions {
                ForEach(sessions, id: \.id) { session in row(session) }
            } else if failed {
                HStack {
                    Text("Could not load your devices.").foregroundStyle(NativePalette.secondary.style)
                    Spacer()
                    Button("Try Again") { Task { await load() } }
                }
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }
            if endFailed {
                Text("Could not sign that device out. Try again.")
                    .font(.caption).foregroundStyle(Colors.dangerText.style)
            }
        }
        .task { await load() }
        .confirmationDialog(
            "Sign Out This Device?", isPresented: Binding(get: { ending != nil }, set: { if !$0 { ending = nil } }),
            presenting: ending
        ) { session in
            Button("Sign Out", role: .destructive) { Task { await end(session) } }
        } message: { session in
            Text("\(Self.name(of: session)) will need to sign in again.")
        }
    }

    private func row(_ session: DeviceSession) -> some View {
        HStack(spacing: Spacing.space3) {
            Image(systemName: session.kind == .browser ? "safari" : "desktopcomputer")
                .foregroundStyle(NativePalette.secondary.style)
                .frame(width: Size.sizeIconLg)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.name(of: session))
                Text(
                    session.current
                        ? String(localized: "This Mac")
                        : String(
                            localized:
                                "Last used \(session.lastUsedAt.date.formatted(.relative(presentation: .named)))")
                )
                .font(.caption).foregroundStyle(NativePalette.secondary.style)
            }
            Spacer()
            if !session.current {
                Button("Sign Out…") { ending = session }
                    .controlSize(.small)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private static func name(of session: DeviceSession) -> String {
        if let name = session.name, !name.isEmpty { return name }
        return session.kind == .browser ? String(localized: "A browser") : String(localized: "A Purlay app")
    }

    private func load() async {
        failed = false
        do {
            sessions = try await model.deviceSessions()
        } catch is CancellationError {
            // The page closed before the list came.
        } catch {
            failed = sessions == nil
        }
    }

    private func end(_ session: DeviceSession) async {
        endFailed = false
        do {
            try await model.endDeviceSession(session.id)
            sessions?.removeAll { $0.id == session.id }
        } catch {
            endFailed = true
        }
    }
}
#endif
