import SwiftUI

struct WheelChoice: Equatable {
    let value: String
    let label: String
}

// The mini-program and native component consume the same reviewed field policy.
struct WheelFieldSpec: Decodable {
    let title: String
    let values: [String]?
    let min: Double?
    let max: Double?
    let step: Double?
    let unit: String?
    let format: String?

    static let all: [String: WheelFieldSpec] = {
        guard let url = Bundle.main.url(forResource: "wheel-fields", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let fields = try? JSONDecoder().decode([String: WheelFieldSpec].self, from: data) else { return [:] }
        return fields
    }()

    private func number(_ value: Double) -> String { String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), value) }
    func key(_ value: String) -> String {
        guard values == nil, !value.isEmpty else { return value }
        if format == "refund", value == "当天" { return "0" }
        guard let range = value.range(of: #"^(-?\d+(?:\.\d+)?)\s*(?:天|个月押金)?$"#, options: .regularExpression), range == value.startIndex..<value.endIndex,
              let prefix = value.range(of: #"^-?\d+(?:\.\d+)?"#, options: .regularExpression),
              let amount = Double(value[prefix]) else { return value }
        return number(amount)
    }
    var choices: [WheelChoice] {
        let strings: [String]
        if let values { strings = values }
        else if let min, let max, let step, step > 0 {
            strings = (0...Int(((max - min) / step).rounded())).map { index in
                let amount = number(min + Double(index) * step)
                if format == "refund", amount == "0" { return "当天" }
                if format == "days" || format == "refund" { return amount + " 天" }
                if format == "deposit" { return amount + " 个月押金" }
                return amount
            }
        } else { strings = [] }
        return [WheelChoice(value: "", label: "未填写")] + strings.map { value in
            WheelChoice(value: value, label: values != nil || (format == "refund" && value == "当天") ? value : key(value) + " " + (unit ?? ""))
        }
    }
    func choices(preserving value: String) -> [WheelChoice] {
        var items = choices
        if !value.isEmpty, !items.contains(where: { key($0.value) == key(value) }) {
            items.insert(WheelChoice(value: value, label: "原记录：" + value), at: 1)
        }
        return items
    }
}

struct WheelInputDraft {
    let spec: WheelFieldSpec
    let original: String
    let choices: [WheelChoice]
    private(set) var index: Int
    private(set) var value: String
    var changed: Bool { spec.key(original) != spec.key(value) }
    init(spec: WheelFieldSpec, value: String) {
        self.spec = spec; original = value; self.value = value
        choices = spec.choices(preserving: value)
        index = choices.firstIndex { spec.key($0.value) == spec.key(value) } ?? 0
    }
    mutating func select(_ index: Int) {
        guard choices.indices.contains(index) else { return }
        self.index = index
        let next = choices[index].value
        value = spec.key(next) == spec.key(original) ? original : next
    }
    mutating func clear() { select(0) }
}

// The caller presents this overlay at the screen root and owns persistence.
// Until confirmation, the component mutates only its private draft.
struct WheelInputDialog: View {
    @State private var draft: WheelInputDraft
    @State private var discarding = false
    let close: () -> Void
    let save: (String) -> Void

    init(spec: WheelFieldSpec, value: String, close: @escaping () -> Void, save: @escaping (String) -> Void) {
        _draft = State(initialValue: WheelInputDraft(spec: spec, value: value))
        self.close = close; self.save = save
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea().contentShape(Rectangle())
                .onTapGesture(perform: cancel).accessibilityLabel("取消选择").accessibilityIdentifier("wheel.mask")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(draft.spec.title).font(.system(size: 18, weight: .semibold))
                    Spacer(minLength: 0)
                    Button(action: cancel) {
                        Image(systemName: "xmark").font(.system(size: 17)).foregroundStyle(XJTheme.muted)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("取消").accessibilityIdentifier("wheel.close")
                }
                Text("滑动选择").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.top, 2)
                Picker(draft.spec.title, selection: Binding(get: { draft.index }, set: { draft.select($0) })) {
                    ForEach(draft.choices.indices, id: \.self) { index in
                        Text(draft.choices[index].label).font(.system(size: 20)).tag(index)
                    }
                }.pickerStyle(.wheel).labelsHidden().frame(height: 220).clipped()
                    .padding(.top, 8).padding(.bottom, 16).accessibilityIdentifier("wheel.picker")
                HStack(spacing: 12) {
                    Button("清空") { draft.clear() }.buttonStyle(MPButtonStyle(kind: .soft)).accessibilityIdentifier("wheel.clear")
                    Button("确定") { save(draft.value) }.buttonStyle(MPButtonStyle(kind: .primary)).accessibilityIdentifier("wheel.confirm")
                }
            }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: XJTheme.ink.opacity(0.16), radius: 24, y: 12)
                .frame(maxWidth: 360).padding(.horizontal, 24)
                .accessibilityElement(children: .contain).accessibilityIdentifier("wheel.dialog")
                .accessibilityHidden(discarding).allowsHitTesting(!discarding)
            if discarding {
                Color.black.opacity(0.18).ignoresSafeArea().onTapGesture { discarding = false }
                VStack(spacing: 0) {
                    Text("是否放弃修改？").font(.system(size: 18, weight: .semibold))
                    Text("本次选择尚未保存").font(.system(size: 13)).foregroundStyle(XJTheme.muted).padding(.top, 10).padding(.bottom, 24)
                    HStack(spacing: 12) {
                        Button("继续编辑") { discarding = false }.buttonStyle(MPButtonStyle(kind: .soft)).accessibilityIdentifier("wheel.keep")
                        Button("放弃修改", action: close).buttonStyle(MPButtonStyle(kind: .danger)).accessibilityIdentifier("wheel.discard")
                    }
                }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 20)
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: XJTheme.ink.opacity(0.2), radius: 20, y: 12).frame(maxWidth: 336).padding(.horizontal, 36)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("wheel.discardDialog")
            }
        }.foregroundStyle(XJTheme.ink)
    }
    private func cancel() { if draft.changed { discarding = true } else { close() } }
}
