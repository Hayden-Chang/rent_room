#if DEBUG
import SwiftUI

struct MeasurementReviewHost: View {
    @State private var minutes = "24"
    @State private var speed = "10"
    @State private var event = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                XJCard {
                    VStack(spacing: 8) {
                        AnswerInput(field: field(UtilityField.transit, "公交地铁通行时间（分钟）"), text: $minutes, otherText: .constant(""), showsKeyboardToolbar: false,
                                    choose: { _ in }, action: { event = $0 }, measurement: MeasurementAction(kind: .commute, perform: { event = "已触发通勤查询，保留手工值" }))
                        AnswerInput(field: field(UtilityField.speed, "实测网速"), text: $speed, otherText: .constant(""), showsKeyboardToolbar: false,
                                    choose: { _ in }, action: { event = $0 }, measurement: MeasurementAction(kind: .speed, perform: { event = "已触发网速测试，尚未下载" }))
                    }
                }
                if !event.isEmpty { Text(event).font(.system(size: 12)).accessibilityIdentifier("review.measurementEvent") }
                Spacer()
            }.padding(16).background(XJTheme.background).navigationTitle("通勤与网速输入").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
        }.tint(XJTheme.primary)
    }
    private func field(_ id: String, _ label: String) -> JSONValue { .object(["id": .string(id), "label": .string(label), "type": .string("n")]) }
}
#endif
