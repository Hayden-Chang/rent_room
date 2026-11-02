#if DEBUG
import SwiftUI

// In-memory interaction review: no account, house, storage, or backend writes.
struct InspectionTeachingReviewHost: View {
    @State private var step = 3
    @State private var field = MPFieldState()
    @State private var days = MPFieldState(text: "0", note: "原有备注")
    @State private var coordinator = MPSwipeCoordinator()
    @State private var events = 0
    private var guide: JSONValue {
        .object(["tutorial": .number(Double(step)), "steps": .array([.null, .null,
            .object(["title": .string("向左滑，试试看"), "pose": .string("think"), "text": .string("在检查项上向左滑一下，试试看！")]),
            .object(["title": .string("随手记下房屋细节"), "pose": .string("success"), "text": .string("这里可以标记问题❗、\n写备注🖊，\n还能拍照📷和录视频。"),
                     "icons": .object(["❗": .string("issue"), "🖊": .string("note"), "📷": .string("camera")])])])])
    }
    var body: some View {
        VStack(spacing: 20) {
            Text("清单操作预览").font(.headline)
            Text("未选择；操作次数：\(events)").accessibilityIdentifier("teaching.events")
            MPCard {
                MPFieldRow(item: MPFieldItem(id: "teaching", title: "窗户密封", options: ["是", "否"]), state: $field,
                    coordinator: coordinator, note: { events += 1 }, capture: { events += 1 })
                    .background {
                        if ProcessInfo.processInfo.arguments.contains("--record-teaching-swipe") {
                            TeachingRevealRecorder().allowsHitTesting(false)
                        }
                    }
                    .anchorPreference(key: CoachAnchors.self, value: .bounds) { [3: $0] }
            }
            if step == 0 {
                MPCard {
                    MPFieldRow(item: MPFieldItem(id: "f5_3", title: "免租期（天）", kind: .number, numberPad: true), state: $days,
                        coordinator: coordinator, note: {}, capture: {})
                }
                Button("收起键盘") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityIdentifier("teaching.dismissKeyboard")
                Text("免租期：\(days.text)；\(days.note)").accessibilityIdentifier("teaching.days")
            }
            Spacer()
        }.padding(16).background(XJTheme.background)
            .onChange(of: field.selected) { _, _ in events += 1 }
            .overlayPreferenceValue(CoachAnchors.self) { anchors in
                GeometryReader { geometry in
                    if step != 0 {
                        XiaodaTutorialOverlay(guide: guide, target: anchors[3].map { geometry[$0] }, swipeCompleted: {
                            coordinator.reveal("teaching"); step = 4
                        }, swipeProgress: { offset in
                            if offset == 0 { coordinator.close() }
                            else { coordinator.move("teaching", x: offset, y: 0, time: ProcessInfo.processInfo.systemUptime) }
                        }, decoratedSpeech: true, next: { step = 0; coordinator.close() })
                    }
                }
            }
    }
}
#endif
