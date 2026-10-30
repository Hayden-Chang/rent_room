import Foundation

/// Complete metadata and house order, with only changed house records. Reuse
/// unchanged value trees; validate the entire result before publishing any state.
enum StateDelta {
    static func apply(_ delta: JSONValue, to previous: JSONValue) throws -> JSONValue {
        guard case .object(let metadata) = delta["metadata"], metadata["houses"] == nil,
              case .array(let order) = delta["order"],
              case .array(let changes) = delta["houses"],
              case .array(let prior) = previous["houses"] else { throw invalid() }
        var records: [String: JSONValue] = [:]
        for house in prior {
            guard !house.id.isEmpty, records[house.id] == nil else { throw invalid() }
            records[house.id] = house
        }
        var changed: Set<String> = []
        for house in changes {
            guard case .object = house, !house.id.isEmpty, changed.insert(house.id).inserted else { throw invalid() }
            records[house.id] = house
        }
        var seen: Set<String> = []
        let houses = try order.map { value -> JSONValue in
            guard case .string(let id) = value, seen.insert(id).inserted,
                  let house = records[id] else { throw invalid() }
            return house
        }
        guard changed.isSubset(of: seen) else { throw invalid() }
        return JSONValue.object(metadata).setting("houses", to: .array(houses))
    }
    private static func invalid() -> CoreFailure { CoreFailure(message: "房源更新数据无效") }
}
