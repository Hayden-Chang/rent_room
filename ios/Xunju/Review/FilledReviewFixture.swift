#if DEBUG
import Foundation

/// Seeds 50 answers only; the 51st answer and return navigation use the real UI.
@MainActor enum FilledReviewFixture {
    static func enabled(_ arguments: [String]) -> Bool {
        ReturningBusinessFixture.enabled(arguments) && arguments.contains("--filled-review-fixture")
    }
    static func creationEnabled(_ arguments: [String]) -> Bool {
        ReturningBusinessFixture.enabled(arguments) && arguments.contains("--review-creation-fixture")
    }

    static func prepare(_ store: NativeStore) throws {
        guard store.houses.isEmpty else { return }
        try store.call("templateSelect", ["value": .string("detailed")])
        let id = try store.add("评分检查项房源")
        for field in store.house(id)["templateTopics"].array.flatMap({ $0["fields"].array }) where field.id != "f1_6" {
            if store.houses.first?.stats.done == 50 { break }
            let value = field["options"].array.first ?? .string(["y", "c", "a"].contains(field["type"].string) ? "是" : "50")
            try store.answer(id, field: field.id, value: value)
        }
        guard store.houses.first?.stats.done == 50 else { throw CoreFailure(message: "评分测试需要恰好 50 个已填写检查项") }
        try store.call("save")
    }
}
#endif
