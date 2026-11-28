#if os(macOS)
import PurlayContract
import PurlayKit
import PurlayTokens
import SwiftUI

/// What an edited message said before (server D-135), newest first: opened from its "edited" mark. Anybody who can read the
/// message can read its versions; its author removes one in the browser.
struct EditHistoryView: View {
    let model: AppModel
    let message: Message
    @State private var versions: [MessageVersion] = []
    @State private var next: Uuid?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit History")
                .font(.headline)
                .padding([.horizontal, .top], Spacing.space4)
                .padding(.bottom, Spacing.space2)
            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 380, height: 360)
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        if loading && versions.isEmpty {
            ProgressView().controlSize(.small)
        } else if failed && versions.isEmpty {
            ContentUnavailableView {
                Label("Could Not Load the History", systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else if versions.isEmpty {
            ContentUnavailableView(
                "No Earlier Versions", systemImage: "clock.arrow.circlepath",
                description: Text("What this message said before was removed."))
        } else {
            List {
                ForEach(versions, id: \.id) { version in
                    VStack(alignment: .leading, spacing: Spacing.space1) {
                        Text("Replaced \(version.replacedAt.date.formatted(date: .abbreviated, time: .shortened))")
                            .typeStyle(Typography.caption)
                            .foregroundStyle(NativePalette.secondary.style)
                        MessageBody(text: version.content)
                    }
                    .padding(.vertical, Spacing.space1)
                    .accessibilityElement(children: .combine)
                }
                if next != nil {
                    Button("Load Earlier Versions") { Task { await load() } }
                        .disabled(loading)
                }
            }
            .listStyle(.plain)
        }
    }

    private func load() async {
        loading = true
        failed = false
        defer { loading = false }
        do {
            let page = try await model.versions(of: message.id, before: versions.last?.id)
            versions += page.data
            next = page.nextCursor
        } catch is CancellationError {
            // The popover closed before the page came: nothing to show it on.
        } catch {
            failed = true
        }
    }
}
#endif
