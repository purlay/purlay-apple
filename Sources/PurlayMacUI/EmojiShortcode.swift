import Foundation

/// An emoji written by its name after a colon, as the web client offers it: `:smi` lists 😄 and its kin, and choosing one puts the
/// emoji in place of what was typed. Only at the start of a word, and only once two letters say what is meant, so a time (`10:30`),
/// an address or a lone colon opens nothing.
enum EmojiShortcode {
    struct Query: Equatable {
        /// Where the colon is, in UTF-16 units: what is replaced runs from here to the caret.
        let start: Int
        let words: String
    }

    static let shownMax = 8
    private static let wordsMin = 2

    static func query(_ text: String, caret: Int) -> Query? {
        let units = Array(text.utf16)
        guard caret > 0, caret <= units.count else { return nil }
        var index = caret - 1
        while index >= 0 {
            let unit = units[index]
            if unit == UInt16(UInt8(ascii: ":")) { break }
            guard let scalar = Unicode.Scalar(unit), isNameCharacter(scalar) else { return nil }
            index -= 1
        }
        guard index >= 0 else { return nil }
        if index > 0 {
            guard let before = Unicode.Scalar(units[index - 1]), CharacterSet.whitespacesAndNewlines.contains(before)
            else { return nil }
        }
        let words = String(decoding: units[(index + 1)..<caret], as: UTF16.self)
        guard words.count >= wordsMin else { return nil }
        return Query(start: index, words: words)
    }

    /// The text with the emoji in place of `:words`, and where the caret goes: just after it.
    static func insert(_ symbol: String, for query: Query, in text: String, caret: Int) -> (text: String, caret: Int) {
        let units = Array(text.utf16)
        let head = String(decoding: units[..<query.start], as: UTF16.self)
        let tail = String(decoding: units[caret...], as: UTF16.self)
        return (head + symbol + tail, query.start + symbol.utf16.count)
    }

    /// What the catalogue finds, those whose name begins with the words first (`:rock` is 🚀 before 🤘, whose keyword it only
    /// is), each group in the catalogue's order.
    static func matches(_ query: Query) -> [ReactionEmoji] {
        let words = query.words.replacingOccurrences(of: "_", with: " ")
        let found = ReactionEmojiCatalog.matching(words)
        let named = found.filter {
            $0.name.range(of: words, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        }
        let rest = found.filter {
            $0.name.range(of: words, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) == nil
        }
        return Array((named + rest).prefix(shownMax))
    }

    /// Letters of any script (a Turkish name is a name), digits, and the joiners names are written with.
    private static func isNameCharacter(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-" || scalar == "+"
    }
}
