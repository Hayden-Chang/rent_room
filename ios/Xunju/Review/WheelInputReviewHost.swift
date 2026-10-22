#if DEBUG
import SwiftUI

// Disposable component state; this host is not the business checklist.
struct WheelInputReviewHost: View {
    @State private var values = ["fc76beec-52e3-4fe9-a937-dec254d4cc4f": "12", "f1_3": "45", "f88_1": "1.5"]
    @State private var editing: String?
    @State private var money = "2800"
    @State private var speed = "83.25"
    @State private var other = ""
    private let ids = ["fc76beec-52e3-4fe9-a937-dec254d4cc4f", "f1_3", "f1_5", "f5_3", "21255282-3663-4abe-b7de-d91eeb3825ed", "3c70cda2-7c6c-4fa6-b2db-b647af24ba72", "f41_3", "f88_1", "f88_2", "f44_1", "f44_0", "f105_0", "f112_2", "f113_1", "f116_1", "f112_5", "f113_2"]
    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        MPCard {
                            VStack(spacing: 0) {
                                ForEach(ids, id: \.self) { id in
                                    if let spec = WheelFieldSpec.all[id] {
                                        HStack(spacing: 12) {
                                            Text(spec.title).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                                            Button { editing = id } label: {
                                                HStack(spacing: 8) {
                                                    Text(display(id, spec)).lineLimit(1)
                                                    Image(systemName: "chevron.down").font(.system(size: 10))
                                                }.font(.system(size: 13)).padding(.horizontal, 12).frame(minWidth: 96, minHeight: 44)
                                                    .background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                                            }.buttonStyle(.plain).accessibilityIdentifier("wheel.open.\(id)").accessibilityValue((values[id] ?? "").isEmpty ? "未填写" : values[id] ?? "")
                                        }.padding(.vertical, 2)
                                        XJTheme.line.frame(height: 1)
                                    }
                                }
                                if values["f1_5"] == "其他" { TextField("请填写其他内容", text: $other).accessibilityIdentifier("wheel.other").padding(.vertical, 12) }
                            }
                        }
                        MPCard {
                            VStack(spacing: 16) {
                                HStack { Text("租金（元/月）"); TextField("填写数值", text: $money).keyboardType(.decimalPad).accessibilityIdentifier("wheel.manual.money") }
                                HStack { Text("实测网速 Mbps"); TextField("网速", text: $speed).keyboardType(.decimalPad).accessibilityIdentifier("wheel.manual.speed") }
                            }.font(.system(size: 13))
                        }
                    }.padding(16)
                }.background(XJTheme.background).navigationTitle("清单轮盘组件").navigationBarTitleDisplayMode(.inline)
            }.allowsHitTesting(editing == nil).accessibilityHidden(editing != nil)
            if let editing, let spec = WheelFieldSpec.all[editing] {
                WheelInputDialog(spec: spec, value: values[editing] ?? "", close: { self.editing = nil }, save: { value in
                    values[editing] = value; self.editing = nil
                }).id(editing)
            }
        }.tint(XJTheme.primary)
    }
    private func display(_ id: String, _ spec: WheelFieldSpec) -> String {
        let value = values[id] ?? ""
        return spec.choices(preserving: value).first { spec.key($0.value) == spec.key(value) }?.label ?? value
    }
}
#endif
