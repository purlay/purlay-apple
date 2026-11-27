import Foundation
import Testing

@testable import PurlayKit

@Suite("what the app remembers between launches")
struct DefaultsOwnerTests {
    @Test("remembers who the retained data belongs to, and forgets it when told")
    func roundTrip() {
        let name = "purlay-tests-" + UUID().uuidString
        defer { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        let owner = DefaultsOwner(suite: name)
        #expect(owner.load() == nil)
        owner.save("user-1")
        #expect(owner.load() == "user-1")
        #expect(DefaultsOwner(suite: name).load() == "user-1", "a later launch finds it")
        owner.save(nil)
        #expect(owner.load() == nil)
    }
}
