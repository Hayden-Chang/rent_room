#if DEBUG
import SwiftUI

struct AnswerReviewHost: View {
    @State private var address = "朝阳路18号"
    @State private var rent = "2800"
    @State private var other = ""
    @State private var direction = "南"
    @State private var carriers: Set<String> = ["联通"]
    @State private var event = ""
    @FocusState private var focus: Bool

    var body: some View {
        XJCard {
            VStack(spacing: 8) {
                AnswerInput(field: field("f1_1", "地址", "t"), text: $address, otherText: .constant(""), choose: { _ in }, action: { event = $0 })
                AnswerInput(field: field("f1_6", "月租金", "n"), text: $rent, otherText: .constant(""), choose: { _ in }, action: { event = $0 })
                AnswerInput(field: field("f1_5", "朝向", "s", choices: ["东", "南", "西", "北", "东南", "西南", "东北", "西北", "其他"], selected: [direction], other: direction == "其他"),
                            text: .constant(""), otherText: $other, choose: { direction = direction == $0 ? "" : $0 }, action: { event = $0 })
                AnswerInput(field: field("f83_2", "运营商", "s", choices: ["移动", "联通", "电信"], selected: carriers, multiple: true),
                            text: .constant(""), otherText: .constant(""), choose: { choice in
                                if carriers.contains(choice) { carriers.remove(choice) } else { carriers.insert(choice) }
                            }, action: { event = $0 })
                if !event.isEmpty { Text(event).accessibilityIdentifier("review.answerEvent") }
            }
        }
    }

    private func field(_ id: String, _ label: String, _ type: String, choices: [String] = [], selected: Set<String> = [], other: Bool = false, multiple: Bool = false) -> JSONValue {
        .object(["id": .string(id), "label": .string(label), "type": .string(type), "other": .bool(other), "multiple": .bool(multiple),
                 "options": .array(choices.map { choice in .object(["value": .string(choice), "label": .string(choice), "selected": .bool(selected.contains(choice))]) })])
    }
}

struct SummaryReviewHost: View {
    @State private var decision = ""
    @State private var note = ""
    var body: some View { SummaryInput(decision: $decision, note: $note) }
}
#endif
