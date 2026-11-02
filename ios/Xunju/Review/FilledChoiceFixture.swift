#if DEBUG
import Foundation

/// Populated-record preconditions in a disposable business-test directory only.
@MainActor enum FilledChoiceFixture {
    static func enabled(_ arguments: [String]) -> Bool {
        ReturningBusinessFixture.enabled(arguments) && arguments.contains("--filled-choice-fixture")
    }

    static func prepare(_ store: NativeStore) throws {
        guard store.houses.count == 3, let id = store.houses.first?.id else { return }
        var house = store.house(id)
        var answers: [String: JSONValue] = [:]
        for field in house["templateTopics"].array.flatMap({ $0["fields"].array }) {
            let value = field["options"].array.first ?? .string(["y", "c", "a"].contains(field["type"].string) ? "是" : "50")
            answers[field.id] = .object(["value": value, "note": .string(String(repeating: "现场记录", count: 200))])
        }
        answers["f1_top"] = .object(["value": .string("否"), "note": .string("已填写的顶楼备注")])
        house = house.setting("answers", to: .object(answers)).setting("name", to: .string("阳光小区"))
        let houses = (0..<30).map { index in
            house.setting("id", to: .string("filled-choice-\(index)"))
                .setting("archived", to: .bool(index > 0))
                .setting("name", to: .string(index == 0 ? "阳光小区" : "已记录房源\(index)"))
        }
        try store.records.write(String(decoding: JSONEncoder().encode(store.state.setting("houses", to: .array(houses))), as: UTF8.self), keepPrevious: false)
    }
}
#endif
