#if DEBUG
import SwiftUI

/// Disposable persistence exercises input retention without opening user records.
struct OutsideInputReviewHost: View {
    private let defaults: UserDefaults
    @State private var rent: MPFieldState
    @State private var furniture: MPFieldState
    @State private var other: MPFieldState
    @State private var decision = ""
    @State private var note: String
    @State private var buttonCount = 0
    @State private var coordinator = MPSwipeCoordinator()
    init() {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--input-review-id")
        let id = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "preview"
        let defaults = UserDefaults(suiteName: "com.keeline.xunju.input-review." + id)!
        self.defaults = defaults
        _rent = State(initialValue: MPFieldState(text: defaults.string(forKey: "rent") ?? ""))
        _furniture = State(initialValue: MPFieldState(text: defaults.string(forKey: "furniture") ?? ""))
        _other = State(initialValue: MPFieldState(otherText: defaults.string(forKey: "other") ?? "", selected: ["其他"]))
        _note = State(initialValue: defaults.string(forKey: "note") ?? "")
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("基本信息").frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("outside.title")
                    VStack(spacing: 0) {
                        MPFieldRow(item: MPFieldItem(id: "rent", title: "租金", kind: .number), state: $rent, coordinator: coordinator, note: {}, capture: {})
                        MPFieldRow(item: MPFieldItem(id: "furniture", title: "缺少的家具", kind: .text), state: $furniture, coordinator: coordinator, note: {}, capture: {})
                        MPFieldRow(item: MPFieldItem(id: "other", title: "朝向", kind: .choice, options: ["南", "其他"]), state: $other, coordinator: coordinator, note: {}, capture: {})
                    }.padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                    Button("标记关注（\(buttonCount)）") { buttonCount += 1 }
                        .buttonStyle(.bordered).accessibilityIdentifier("outside.action")
                    SummaryInput(decision: $decision, note: $note)
                    Color.clear.frame(height: 60).contentShape(Rectangle()).accessibilityIdentifier("outside.blank")
                }.padding(16)
            }.background(XJTheme.background)
                .navigationTitle("输入交互评审").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityIdentifier("outside.done")
                } }
        }.finishInputOnOutsideTap()
            .onChange(of: rent.text) { defaults.set(rent.text, forKey: "rent") }
            .onChange(of: furniture.text) { defaults.set(furniture.text, forKey: "furniture") }
            .onChange(of: other.otherText) { defaults.set(other.otherText, forKey: "other") }
            .onChange(of: note) { defaults.set(note, forKey: "note") }
    }
}
#endif
