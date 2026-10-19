import Foundation

/// Lossless access to the shared mini-program schema, including old backup fields.
enum JSONValue: Codable, Equatable, Hashable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(_ key: String) -> JSONValue {
        if case .object(let value) = self { return value[key] ?? .null }
        return .null
    }
    func setting(_ key: String, to value: JSONValue) -> JSONValue {
        guard case .object(var object) = self else { return self }
        object[key] = value
        return .object(object)
    }
    func removing(_ key: String) -> JSONValue {
        guard case .object(var object) = self else { return self }
        object.removeValue(forKey: key)
        return .object(object)
    }
    var array: [JSONValue] { if case .array(let value) = self { return value }; return [] }
    var string: String {
        switch self {
        case .string(let value): value
        case .number(let value): value.formatted(.number.grouping(.never).precision(.fractionLength(0...12)))
        default: ""
        }
    }
    var bool: Bool { if case .bool(let value) = self { return value }; return false }
    var int: Int { if case .number(let value) = self { return Int(value) }; return 0 }
    var id: String { self["id"].string }
}

struct CoreFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
