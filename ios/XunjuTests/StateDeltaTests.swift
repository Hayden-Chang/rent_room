import XCTest
@testable import Xunju

final class StateDeltaTests: XCTestCase {
    private let old: JSONValue = .object(["houses": .array([
        .object(["id": .string("a"), "unknown": .string("保留")]), .object(["id": .string("b")])
    ]), "removedMetadata": .bool(true)])
    private func delta(_ order: [String], _ houses: [JSONValue] = []) -> JSONValue {
        .object(["metadata": .object(["settings": .object(["onboarding": .bool(false)])]),
                 "order": .array(order.map(JSONValue.string)), "houses": .array(houses)])
    }
    func testChangeReorderRemoveAndMetadataReplacementAreLossless() throws {
        let changed: JSONValue = .object(["id": .string("b"), "answers": .object(["zero": .number(0)])])
        let added: JSONValue = .object(["id": .string("c")])
        let result = try StateDelta.apply(delta(["b", "c", "a"], [changed, added]), to: old)
        XCTAssertEqual(result["houses"].array, [changed, added, old["houses"].array[0]])
        XCTAssertEqual(result["removedMetadata"], .null)
        XCTAssertEqual(result["settings"]["onboarding"], .bool(false))
        XCTAssertEqual(try StateDelta.apply(delta(["a"]), to: result)["houses"].array, [old["houses"].array[0]])
        XCTAssertEqual(try StateDelta.apply(delta([]), to: result)["houses"].array, [])
    }
    func testMalformedDeltaRejectsWithoutChangingPriorState() {
        let changed: JSONValue = .object(["id": .string("b")])
        for invalid in [delta(["missing"]), delta(["a", "a"]), delta(["a"], [changed]),
                        delta(["b"], [changed, changed]), delta(["a"]).setting("order", to: .null),
                        delta([]).setting("metadata", to: .object(["houses": .array([])]))] {
            XCTAssertThrowsError(try StateDelta.apply(invalid, to: old))
        }
        XCTAssertThrowsError(try StateDelta.apply(delta([]), to: .null))
        XCTAssertEqual(old["houses"].array.count, 2)
    }
}
