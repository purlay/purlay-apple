import Foundation
import PurlayContract
import Testing

@testable import PurlayUI

@Suite("emoji by name in the message box")
struct EmojiShortcodeTests {
    private func caretAtEnd(_ text: String) -> EmojiShortcode.Query? {
        EmojiShortcode.query(text, caret: text.utf16.count)
    }

    @Test("a colon at the start of a word, and two letters after it, ask for an emoji")
    func asks() {
        #expect(caretAtEnd(":ro") == EmojiShortcode.Query(start: 0, words: "ro"))
        #expect(caretAtEnd("ship it :rock") == EmojiShortcode.Query(start: 8, words: "rock"))
        #expect(caretAtEnd("line\n:thumbs_up") == EmojiShortcode.Query(start: 5, words: "thumbs_up"))
        #expect(caretAtEnd("çok :teşekkür") == EmojiShortcode.Query(start: 4, words: "teşekkür"))
    }

    @Test("a time, an address, a lone colon or one letter open nothing")
    func quiet() {
        #expect(caretAtEnd("at 10:30") == nil)
        #expect(caretAtEnd("https://purlay.app") == nil)
        #expect(caretAtEnd("note:") == nil)
        #expect(caretAtEnd(":") == nil)
        #expect(caretAtEnd(":r") == nil)
        #expect(caretAtEnd(":ro ") == nil, "a space ends the name")
        #expect(EmojiShortcode.query(":rocket", caret: 0) == nil)
    }

    @Test("names are found as the catalogue finds them, and the list is short")
    func matches() throws {
        let rocket = try #require(caretAtEnd(":rocket"))
        #expect(EmojiShortcode.matches(rocket).first?.symbol == "🚀")
        let thumbs = try #require(caretAtEnd(":thumbs_up"))
        #expect(EmojiShortcode.matches(thumbs).map(\.symbol).contains("👍"))
        let wide = try #require(caretAtEnd(":fa"))
        #expect(EmojiShortcode.matches(wide).count <= EmojiShortcode.shownMax)
    }

    @Test("the emoji takes the place of the colon and the name, and the caret follows it")
    func inserts() throws {
        let text = "ship it :rock now"
        let query = try #require(EmojiShortcode.query(text, caret: 13))
        let edited = EmojiShortcode.insert("🚀", for: query, in: text, caret: 13)
        #expect(edited.text == "ship it 🚀 now")
        #expect(edited.caret == "ship it 🚀".utf16.count)
    }
}

@Suite("forwarding a message, and adding people to a channel")
struct ForwardAndAddPeopleTests {
    private let link = URL(string: "https://purlay.app/acme/c/1/m/2")!

    @Test("a forward is the note, then the original's link on a line of its own; with no note, the link alone")
    func content() {
        #expect(
            ForwardSheet.content(note: "  have a look  ", link: link)
                == "have a look\n\nhttps://purlay.app/acme/c/1/m/2")
        #expect(ForwardSheet.content(note: " \n ", link: link) == "https://purlay.app/acme/c/1/m/2")
    }

    @Test("those offered are not in the channel yet, match by name or handle without case or accents, by name")
    func candidates() throws {
        func person(_ n: Int, _ name: String, _ handle: String) throws -> User {
            User(
                avatarUrl: nil, displayName: name, id: try #require(Uuid("0199155c-6200-7b7f-8c11-00000000000\(n)")),
                username: handle)
        }
        let ada = try person(1, "Ada", "ada")
        let cem = try person(2, "Cem Öztürk", "cem")
        let bea = try person(3, "Bea", "bea")
        let all = [cem, bea, ada]
        #expect(
            AddPeopleSheet.candidates(all, excluding: [ada.id], query: "").map(\.displayName) == ["Bea", "Cem Öztürk"])
        #expect(AddPeopleSheet.candidates(all, excluding: [], query: "ozturk").map(\.username) == ["cem"])
        #expect(AddPeopleSheet.candidates(all, excluding: [], query: "BE").map(\.username) == ["bea"])
    }
}
