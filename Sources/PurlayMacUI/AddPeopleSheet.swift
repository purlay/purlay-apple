import PurlayContract
import PurlayKit
import PurlayTokens
import SwiftUI

/// People of the workspace added to a channel the person is in. The server decides who may add whom; a refusal is said here and
/// those already added stay added.
struct AddPeopleSheet: View {
    let model: AppModel
    let channel: Channel
    /// Who is in the channel already: not offered again.
    let members: Set<Uuid>
    let added: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var chosen: Set<Uuid> = []
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        let candidates = Self.candidates(model.workspacePeople, excluding: members, query: query)
        VStack(alignment: .leading, spacing: Spacing.space3) {
            Text("Add People to \(Words.channelLabel(channel))").font(.title2.bold()).lineLimit(1)
            TextField("Search people", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search people")
            if candidates.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "Everybody Is Here" : "No Matches", systemImage: "person.2",
                    description: Text(
                        query.isEmpty
                            ? "Everybody in the workspace is in this channel." : "Nobody else matches that name.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(candidates, id: \.id, selection: $chosen) { person in
                    HStack(spacing: Spacing.space2) {
                        Avatar(user: person, size: Size.sizeAvatarSm)
                        Text(person.displayName).lineLimit(1)
                        Text("@\(person.username)").foregroundStyle(NativePalette.secondary.style).lineLimit(1)
                    }
                    .tag(person.id)
                }
                .listStyle(.bordered)
                .frame(minHeight: 200)
            }
            if failed {
                Text("Some people could not be added. You may not be allowed to add people here.")
                    .font(.callout)
                    .foregroundStyle(Colors.dangerText.style)
            }
            HStack {
                Text(chosen.isEmpty ? "" : String(localized: "\(chosen.count) selected"))
                    .foregroundStyle(NativePalette.secondary.style)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { Task { await add() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosen.isEmpty || busy)
            }
        }
        .padding(Spacing.space5)
        .frame(width: 420, height: 480)
        .task { if model.workspacePeople.isEmpty { _ = await model.refreshPeople() } }
    }

    /// Who could be added: not already in, matching the words by name or handle, without case or accents, by name.
    nonisolated static func candidates(_ people: [User], excluding members: Set<Uuid>, query: String) -> [User] {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        return
            people
            .filter { person in
                !members.contains(person.id)
                    && (wanted.isEmpty || person.displayName.localizedStandardContains(wanted)
                        || person.username.localizedStandardContains(wanted))
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func add() async {
        busy = true
        failed = false
        defer { busy = false }
        var any = false
        for person in chosen {
            do {
                try await model.addMember(person, to: channel.id)
                chosen.remove(person)
                any = true
            } catch {
                failed = true
            }
        }
        if any { added() }
        if !failed { dismiss() }
    }
}
