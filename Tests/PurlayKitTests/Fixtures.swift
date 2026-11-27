import Foundation
import PurlayContract

/// The server's own fixtures, from the pinned bundle: what a second implementation is held to.
enum Fixtures {
    static func json(_ path: String) throws -> JSONValue {
        // Tests/PurlayKitTests/Fixtures.swift → the repository root.
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("Contract/bundle/fixtures/" + path))
        // Not JSONDecoder: the Markdown corpus holds trees two hundred values deep, past what the app reads from a server
        // (`JSONValue.depthMax`). It is the server's own test data, which the app never reads, so it is read here without
        // that bound, through Foundation's parser and a converter whose frames are small.
        return try value(JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed))
    }

    struct NotJSON: Error {}

    private static func value(_ object: Any) throws -> JSONValue {
        switch object {
        case is NSNull: return .null
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            if CFNumberIsFloatType(number) { return .number(number.doubleValue) }
            return .integer(number.intValue)
        case let text as String: return .string(text)
        case let items as [Any]: return .array(try items.map(value))
        case let fields as [String: Any]: return .object(try fields.mapValues(value))
        default: throw NotJSON()
        }
    }
}

extension JSONValue {
    subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { return object[key] }
        return nil
    }

    var array: [JSONValue] {
        if case .array(let items) = self { return items }
        return []
    }

    var text: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var int: Int? {
        if case .integer(let value) = self { return value }
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    var boolean: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}
