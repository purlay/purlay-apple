import Foundation
import PurlayWords
import Testing

/// The sentences both apps' screens say, read from PurlayWords' own catalogue in each language.
@Suite("the words both apps' screens share")
struct SharedWordsTests {
    private func text(_ resource: LocalizedStringResource, in language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test("every sentence is translated: in Turkish it is not the English one")
    func translated() {
        for sentence in SharedWords.fixed + [SharedWords.unread(2)] {
            let english = text(sentence, in: "en")
            let turkish = text(sentence, in: "tr")
            #expect(!english.isEmpty && !turkish.isEmpty)
            #expect(turkish != english, "not translated: \(english)")
        }
    }

    @Test("the words the two apps used to say differently are one: the Mac's, which shipped")
    func oneWording() {
        #expect(text(SharedWords.cancel, in: "tr") == "İptal")
        #expect(text(SharedWords.jumpToLatest, in: "tr") == "En Yeniye Git")
        #expect(text(SharedWords.signOutEverywhere, in: "tr") == "Her Yerde Oturumu Kapat")
    }

    @Test("an unread count says its number, in each language")
    func unread() {
        #expect(text(SharedWords.unread(1), in: "en") == "1 unread")
        #expect(text(SharedWords.unread(3), in: "tr") == "3 okunmamış")
    }
}
