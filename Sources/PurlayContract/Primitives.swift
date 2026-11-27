import Foundation

// What the generated types stand on. Written by hand because the contract names these shapes by format
// (`uuid`, `date-time`) and a client has to decide how each one is held and spelled.

/// A UUID as the server spells it: lower case, hyphenated, compared as text.
///
/// `Foundation.UUID` encodes in upper case, and message ids are ordered by comparing their text (a version 7 id
/// carries its time in the leading digits), so an id that changed case on the way out would sort and compare
/// differently from the one the server sent. This keeps the server's spelling and refuses what is not a UUID.
public struct Uuid: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let value: String

    /// The shape: 8-4-4-4-12 hexadecimal digits, any case on the way in.
    public init?(_ string: String) {
        let bytes = Array(string.utf8)
        guard bytes.count == 36 else { return nil }
        for (index, byte) in bytes.enumerated() {
            if [8, 13, 18, 23].contains(index) {
                guard byte == UInt8(ascii: "-") else { return nil }
            } else {
                let isDigit = (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                let isLower = (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
                let isUpper = (UInt8(ascii: "A")...UInt8(ascii: "F")).contains(byte)
                guard isDigit || isLower || isUpper else { return nil }
            }
        }
        value = string.lowercased()
    }

    public init(_ uuid: UUID) {
        // `UUID.uuidString` is upper case and always well formed.
        value = uuid.uuidString.lowercased()
    }

    public var description: String { value }

    public static func < (left: Uuid, right: Uuid) -> Bool { left.value < right.value }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = Uuid(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "not a UUID: \(text)"))
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// An instant as the server spells it: ISO 8601 in UTC, with milliseconds (`2026-09-09T08:00:00.000Z`).
/// Read with or without the fractional part; always written with it.
public struct Timestamp: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let date: Date

    public init(_ date: Date) {
        self.date = date
    }

    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    public init?(_ string: String) {
        if let parsed = try? Date(string, strategy: Self.withFraction) {
            date = parsed
        } else if let parsed = try? Date(string, strategy: Self.withoutFraction) {
            date = parsed
        } else {
            return nil
        }
    }

    public var description: String { date.formatted(Self.withFraction) }

    public static func < (left: Timestamp, right: Timestamp) -> Bool { left.date < right.date }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = Timestamp(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "not a timestamp: \(text)"))
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// Any JSON, held as it came: what an unknown frame, an unknown union member or a schema with no shape is read as.
public enum JSONValue: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// How many arrays and objects deep a document may nest, counted from its top (`[[0]]` is two). A value of any shape
    /// is read recursively, and each level costs stack: a document nested far enough ends the app, which a server must
    /// never be able to do. The contract's deepest answer is seven deep (a page of items holding lists of objects), so
    /// this is nine times that.
    public static let depthMax = 64

    /// A document nested deeper than `depthMax`: not read, rather than read until the stack runs out.
    public struct TooDeep: Error, Sendable, Equatable {
        public let depthMax: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            // Only an array or an object recurses, so only they are counted. The coding path is the way down from the
            // top of the document: a value inside a typed answer counts the levels above it too.
            guard decoder.codingPath.count < Self.depthMax else { throw TooDeep(depthMax: Self.depthMax) }
            // Only "this is not an array" moves on to reading an object: an error from inside the array (its nesting
            // among them) is the answer.
            do {
                self = .array(try container.decode([JSONValue].self))
            } catch DecodingError.typeMismatch(_, let context)
                where context.codingPath.count == decoder.codingPath.count
            {
                self = .object(try container.decode([String: JSONValue].self))
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
