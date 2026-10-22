import Foundation

/// Adapts the shared mini-program form without reconstructing its hierarchy or
/// visibility rules in Swift. Folding must never write an answer.
enum ChecklistPresentation {
    static func item(_ field: JSONValue, hideDivider: Bool = false) -> MPFieldItem {
        let heading = field["heading"].string
        let kind: MPFieldItem.Kind = heading == "category" ? .category : heading == "group" ? .group : field["wheel"].bool ? .wheel :
            !field["options"].array.isEmpty ? .choice : field["type"].string == "n" ? .number :
            field["type"].string == "d" ? .date : .text
        let stats = field["stats"]
        return MPFieldItem(id: field.id, title: field["label"].string, kind: kind,
            options: field["options"].array.map { $0["value"].string },
            labels: Dictionary(uniqueKeysWithValues: field["options"].array.map { ($0["value"].string, $0["label"].string) }),
            multiple: field["multiple"].bool, inline: field["inline"].bool, skippable: field["skippable"].bool,
            hideDivider: hideDivider,
            stats: stats == .null ? "" : "\(stats["done"].int) / \(stats["total"].int)" + (stats["issues"].int > 0 ? " · \(stats["issues"].int) 问题" : ""),
            photoRef: field["photoRef"].string, collapsible: field["expanded"] != .null)
    }

    static func state(_ field: JSONValue) -> MPFieldState {
        MPFieldState(text: field["value"].string, note: field["note"].string, otherText: field["otherText"].string,
            selected: Set(field["options"].array.filter { $0["selected"].bool }.map { $0["value"].string }),
            flagged: field["problem"].bool, expanded: field["expanded"].bool, skipped: field["skipped"].bool)
    }

    static func indent(_ row: JSONValue) -> Double { Double(min(2, max(0, row["depth"].int)) * 12) }
    static func hidesDivider(at index: Int, rows: [JSONValue]) -> Bool {
        rows.indices.contains(index + 1) && rows[index + 1]["kind"].string == "group"
    }

    @MainActor static func write(_ new: MPFieldState, from field: JSONValue, houseID: String, store: NativeStore) throws {
        let old = state(field)
        if new.text != old.text { try store.answer(houseID, field: field.id, value: .string(String(new.text.prefix(2000)))) }
        if new.otherText != old.otherText { try store.answer(houseID, field: field.id, property: "otherText", value: .string(String(new.otherText.prefix(2000)))) }
        if new.flagged != old.flagged { try store.answer(houseID, field: field.id, property: "issueFlag", value: .bool(new.flagged)) }
        // Preserve canonical choice toggling, multi-selection order and group rules.
        for option in field["options"].array.map({ $0["value"].string }) where new.selected.contains(option) != old.selected.contains(option) {
            if !field["multiple"].bool, !new.selected.isEmpty, !new.selected.contains(option) { continue }
            try store.call("choose", ["id": .string(houseID), "field": .string(field.id), "value": .string(option)])
        }
    }
}
