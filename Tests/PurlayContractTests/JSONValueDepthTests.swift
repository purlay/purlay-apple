import Foundation
import Testing

@testable import PurlayContract

/// A value of any shape is read recursively, so how deep it may nest is bounded: a server that sends more is refused with an
/// error, where reading on would exhaust the stack and end the app (the iOS simulator's test process did, at two hundred).
@Suite("JSONValue nesting")
struct JSONValueDepthTests {
    /// `containers` arrays, one inside the other, around a number: `[[0]]` is two.
    private func nested(containers: Int) -> Data {
        let text = String(repeating: "[", count: containers) + "0" + String(repeating: "]", count: containers)
        return Data(text.utf8)
    }

    @Test("a document nested as deep as the limit is read, to its innermost value")
    func atTheLimit() throws {
        var value = try JSONDecoder().decode(JSONValue.self, from: nested(containers: JSONValue.depthMax))
        var levels = 0
        while case .array(let items) = value, let first = items.first {
            value = first
            levels += 1
        }
        #expect(value == .integer(0))
        #expect(levels == JSONValue.depthMax)
    }

    @Test("one level deeper is refused with the nesting error, not a crash")
    func pastTheLimit() {
        #expect(throws: JSONValue.TooDeep(depthMax: JSONValue.depthMax)) {
            try JSONDecoder().decode(JSONValue.self, from: nested(containers: JSONValue.depthMax + 1))
        }
    }

    @Test("objects are bounded as arrays are")
    func objectsPastTheLimit() {
        let containers = JSONValue.depthMax + 1
        let text = String(repeating: #"{"a":"#, count: containers) + "0" + String(repeating: "}", count: containers)
        #expect(throws: JSONValue.TooDeep(depthMax: JSONValue.depthMax)) {
            try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        }
    }

    @Test("the depth is counted from the top of the document, so a value deep inside a typed answer is bounded too")
    func countedFromTheDocument() {
        struct Envelope: Decodable { let payload: [JSONValue] }
        // The envelope and its array are two of the limit.
        let containers = JSONValue.depthMax - 1
        let inner = String(repeating: "[", count: containers) + String(repeating: "]", count: containers)
        #expect(throws: JSONValue.TooDeep(depthMax: JSONValue.depthMax)) {
            try JSONDecoder().decode(Envelope.self, from: Data(#"{"payload":[\#(inner)]}"#.utf8))
        }
    }

    @Test("a hostile document far deeper than any limit is refused, and the process lives")
    func hostile() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(JSONValue.self, from: nested(containers: 100_000))
        }
    }

}
