import SwiftUI

enum InspectionMode: String, CaseIterable {
    case simple, detailed
    var title: String { self == .simple ? "精简模式" : "详细模式" }
    var detail: String { self == .simple ? "整体判断，补充备注" : "展开细节，逐项记录" }
}

// A value draft: callers decide when and where to persist it. Existing houses
// must keep their own checklist snapshots when this preference is changed.
struct InspectionTemplateDraft: Equatable {
    var order: [String]
    var disabled: Set<String> = []

    init(order: [String], disabled: Set<String> = []) { self.order = order; self.disabled = disabled }
    init(_ value: JSONValue) {
        order = value["order"].array.map(\.string)
        disabled = Set(value["disabled"].array.map(\.string))
    }
    var json: JSONValue { .object(["order": .array(order.map(JSONValue.string)), "disabled": .array(order.filter { disabled.contains($0) }.map(JSONValue.string))]) }

    mutating func toggle(_ category: String) -> String? {
        guard order.contains(category) else { return "清单排序数据无效" }
        if disabled.contains(category) { disabled.remove(category); return nil }
        guard order.filter({ !disabled.contains($0) }).count > 1 else { return "至少保留一个检查大项。" }
        disabled.insert(category)
        return nil
    }

    mutating func move(_ category: String, to target: String) {
        guard let from = order.firstIndex(of: category), let to = order.firstIndex(of: target), from != to else { return }
        order.insert(order.remove(at: from), at: to)
    }
}

enum SetupStyle {
    static let purple = Color(red: 97 / 255, green: 89 / 255, blue: 232 / 255)
    static let ink = Color(red: 52 / 255, green: 59 / 255, blue: 77 / 255)
    static let border = Color(red: 226 / 255, green: 229 / 255, blue: 236 / 255)
    static let soft = Color(red: 246 / 255, green: 245 / 255, blue: 255 / 255)
}

struct XiaodaGreeting: View {
    var body: some View {
        HStack(spacing: 14) {
            Image("xiaoda-greet").resizable().scaledToFit().frame(width: 88, height: 104)
                .accessibilityHidden(true)
            AppText("你好呀！我是小搭。\n先让我了解一下你的偏好，\n给你最关心的事情排个序吧！")
                .font(.system(size: 16)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(SetupStyle.ink).padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(SetupStyle.border, lineWidth: 2))
                .overlay(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: -8, y: 8))
                        path.addLine(to: CGPoint(x: 0, y: 16))
                    }.stroke(SetupStyle.border, lineWidth: 2).frame(width: 1, height: 16)
                }
        }
    }
}

struct InspectionTemplateEditor: View {
    @Binding var draft: InspectionTemplateDraft
    @State private var error = ""
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var dragFrames: [String: CGRect]?
    @GestureState private var drag: TemplateDrag?
    @State private var scroll = NativeScrollPosition()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(draft.order, id: \.self) { title in
                    HStack(spacing: 0) {
                        AppText("≡")
                            .font(.system(size: 20)).foregroundStyle(Color(red: 154/255, green: 158/255, blue: 178/255))
                            .frame(width: 54, height: 66).contentShape(Rectangle())
                            .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .updating($drag) { value, state, _ in
                                    state = TemplateDrag(title: title, translation: value.translation.height)
                                }.onChanged { value in
                                    if dragFrames == nil { dragFrames = layoutFrames() }
                                    scroll.track(value.location)
                                }.onEnded { value in
                                    let target = destination(TemplateDrag(title: title, translation: value.translation.height))
                                    // The drag offsets already preview this order. Commit the layout
                                    // without replaying a move from the rows' original positions.
                                    var transaction = Transaction(animation: nil)
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        scroll.stop()
                                        draft.move(title, to: target)
                                    }
                                })
                            .accessibilityLabel(AppCopy.text("拖动\(AppCopy.text(title))"))
                            .accessibilityIdentifier("setup.drag.\(title)")
                            .accessibilityAction(named: AppCopy.text("上移")) { move(title, offset: -1) }
                            .accessibilityAction(named: AppCopy.text("下移")) { move(title, offset: 1) }
                        AppText(title).font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(draft.disabled.contains(title) ? Color(red: 182/255, green: 185/255, blue: 198/255) : Color(red: 41/255, green: 50/255, blue: 75/255))
                            .strikethrough(draft.disabled.contains(title))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                            .accessibilityIdentifier("setup.title.\(title)")
                        Button {
                            error = draft.toggle(title) ?? ""
                        } label: {
                            MPTrashIcon(disabled: draft.disabled.contains(title)).frame(width: 24, height: 24).frame(width: 48, height: 48)
                        }.buttonStyle(.plain).padding(.leading, 8).padding(.trailing, 12)
                            .accessibilityLabel(AppCopy.text("\(draft.disabled.contains(title) ? "恢复" : "停用")\(title)"))
                            .accessibilityIdentifier("setup.toggle.\(title)")
                    }
                    .frame(minHeight: 66)
                    .background(drag?.title == title ? XJTheme.soft : draft.disabled.contains(title) ? XJTheme.background : .white)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[title] = $0 }
                    .offset(y: offset(title)).zIndex(drag?.title == title ? 1 : 0)
                    if title != draft.order.last { Color(red: 238/255, green: 240/255, blue: 246/255).frame(height: 1) }
                }
            }
                .background(NativeScrollProbe(position: scroll))
                .onChange(of: drag?.title) { _, value in if value == nil { scroll.stop(); dragFrames = nil } }
                .onDisappear { scroll.stop(); dragFrames = nil }
                .padding(2).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(SetupStyle.border, lineWidth: 2))
            if !error.isEmpty {
                AppText(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12)
                    .accessibilityIdentifier("setup.error")
            }
        }
    }

    private func move(_ title: String, offset: Int) {
        guard let index = draft.order.firstIndex(of: title), draft.order.indices.contains(index + offset) else { return }
        draft.move(title, to: draft.order[index + offset])
    }

    private func layoutFrames() -> [String: CGRect] {
        // Row origins reported by a reused GeometryReader can retain the previous
        // order after a drop. Heights plus the current stack order define the layout.
        var top: CGFloat = 0
        return Dictionary(uniqueKeysWithValues: draft.order.map { title in
            let height = rowHeights[title] ?? 66
            let frame = CGRect(x: 0, y: top, width: 0, height: height)
            top += height + 1 // One-point divider between rows.
            return (title, frame)
        })
    }

    private func destination(_ drag: TemplateDrag) -> String {
        let positions = dragFrames ?? layoutFrames()
        guard let start = positions[drag.title] else { return drag.title }
        let center = start.midY + drag.translation + scroll.dragOffset
        return draft.order.min { abs((positions[$0]?.midY ?? center) - center) < abs((positions[$1]?.midY ?? center) - center) } ?? drag.title
    }

    private func offset(_ title: String) -> CGFloat {
        guard let drag, let from = draft.order.firstIndex(of: drag.title),
              let to = draft.order.firstIndex(of: destination(drag)), let index = draft.order.firstIndex(of: title) else { return 0 }
        if title == drag.title { return drag.translation + scroll.dragOffset }
        let height = (dragFrames?[drag.title]?.height ?? rowHeights[drag.title] ?? 66) + 1
        if from < to && index > from && index <= to { return -height }
        if from > to && index >= to && index < from { return height }
        return 0
    }
}

private struct TemplateDrag: Equatable { let title: String; let translation: CGFloat }

struct InspectionModeChoice: View {
    @Binding var selection: InspectionMode
    var showsExamples = true
    private let details = ["外卖能上楼", "超市 / 便利店", "附近有菜市场", "附近有餐饮", "附近有药店", "附近有医院", "附近有快递"]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(InspectionMode.allCases, id: \.self) { mode in
                VStack(alignment: .leading, spacing: 12) {
                    Button { selection = mode } label: {
                        HStack(spacing: 8) {
                            Circle().fill(.white).overlay(Circle().strokeBorder(selection == mode ? SetupStyle.purple : Color(red: 181/255, green: 186/255, blue: 200/255), lineWidth: selection == mode ? 6 : 1.5)).frame(width: 20, height: 20)
                            if !showsExamples {
                                VStack(alignment: .leading, spacing: 4) { title(mode); subtitle(mode) }
                            } else { ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) { title(mode); subtitle(mode) }
                                VStack(alignment: .leading, spacing: 4) { title(mode); subtitle(mode) }
                            }
                            }
                            Spacer(minLength: 0)
                        }.padding(.vertical, showsExamples ? 0 : 8).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("setup.mode.\(mode.rawValue)")
                        .accessibilityLabel(AppCopy.text(mode.title)).accessibilityValue(AppCopy.text(selection == mode ? "已选择" : "未选择"))
                        .accessibilityAddTraits(selection == mode ? .isSelected : [])
                    if showsExamples { VStack(alignment: .leading, spacing: 8) {
                        AppText("示例").font(.system(size: 12, weight: .semibold)).foregroundStyle(XJTheme.muted)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(XJTheme.background, in: RoundedRectangle(cornerRadius: 5))
                        if mode == .simple { simpleExample } else { detailedExample }
                    }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12)) }
                }.padding(.horizontal, 16).padding(.vertical, 14)
                    .background(selection == mode ? SetupStyle.soft : .white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selection == mode ? SetupStyle.purple : SetupStyle.border, lineWidth: 2))
                    .compositingGroup().shadow(color: selection == mode ? Color(red: 217/255, green: 214/255, blue: 251/255) : .clear, radius: 0, y: 3)
            }
        }
    }

    private func title(_ mode: InspectionMode) -> some View {
        AppText(mode.title).font(.system(size: 18, weight: .bold)).foregroundStyle(selection == mode ? Color(red: 81/255, green: 73/255, blue: 207/255) : SetupStyle.ink).frame(minHeight: 27)
    }
    private func subtitle(_ mode: InspectionMode) -> some View {
        AppText(showsExamples ? mode.detail : (mode == .simple ? "90个检查项，突出重点" : "200+检查项，更加全面")).font(.system(size: 14)).foregroundStyle(Color(red: 96/255, green: 107/255, blue: 125/255)).frame(minHeight: 21)
    }
    private var simpleExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppText("生活配套方便").font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 8)
                answer("是", problem: false); answer("否", problem: true)
            }
            AppText("看看附近的超市、菜市场、餐饮、药店、医院和快递，以及外卖能否上楼。")
                .font(.system(size: 14)).lineSpacing(5).foregroundStyle(XJTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                AppText("备注").foregroundStyle(XJTheme.muted)
                AppText("附近没有菜市场").foregroundStyle(XJTheme.danger)
                Spacer(minLength: 0)
            }.font(.system(size: 14)).padding(10).background(XJTheme.dangerBackground, in: RoundedRectangle(cornerRadius: 8))
        }.fixedSize(horizontal: false, vertical: true)
    }
    private var detailedExample: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("生活配套").font(.system(size: 16, weight: .semibold)).padding(.bottom, 6)
            ForEach(details, id: \.self) { label in
                let problem = label == "附近有菜市场"
                HStack {
                    AppText(label).font(.system(size: 14)).foregroundStyle(problem ? XJTheme.danger : SetupStyle.ink)
                    Spacer(); answer(problem ? "否" : "是", problem: problem)
                }.padding(.horizontal, 6).frame(minHeight: 38)
                    .background(problem ? XJTheme.dangerBackground : .clear, in: RoundedRectangle(cornerRadius: 6))
                if label != details.last { Divider() }
            }
        }
    }
    private func answer(_ text: String, problem: Bool) -> some View {
        AppText(text).font(.system(size: 14, weight: problem ? .semibold : .regular))
            .foregroundStyle(problem ? XJTheme.danger : XJTheme.muted)
            .frame(width: 32, height: 28)
            .background(problem ? XJTheme.dangerBackground : XJTheme.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct InspectionSetupSurface: View {
    @Binding var draft: InspectionTemplateDraft
    @Binding var mode: InspectionMode
    @State private var choosingMode = false
    var conciseWelcome = false
    var initialStep = "sort"
    var changeStep: (String) -> Bool = { _ in true }
    var finish: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 6) {
                        Capsule().fill(SetupStyle.purple).frame(height: 8)
                        Capsule().fill(choosingMode ? SetupStyle.purple : SetupStyle.border).frame(height: 8)
                        AppText(choosingMode ? "2 / 2" : "1 / 2").font(.system(size: 12, weight: .semibold)).padding(.leading, 10)
                    }.foregroundStyle(XJTheme.muted).id("setup.top")
                    VStack(alignment: .leading, spacing: 8) {
                        if !choosingMode && !conciseWelcome {
                            AppText("和小搭一起，准备看房").font(.system(size: 12, weight: .semibold)).foregroundStyle(XJTheme.muted)
                        }
                        AppText(choosingMode ? "选一种记录方式" : "定制你的看房清单")
                            .font(.system(size: 24, weight: .bold)).foregroundStyle(SetupStyle.ink)
                    }
                    if choosingMode { InspectionModeChoice(selection: $mode, showsExamples: !conciseWelcome) }
                    else {
                        if conciseWelcome {
                            XiaodaMessage(text: "你好呀！我是小搭。\n拖动 ☰ 可以排序，\n点击 🗑 可以删除哦～", pose: "greet", compact: false,
                                highlights: ["排序", "删除"], icons: ["☰": "handle", "🗑": "trash"], highlightColor: Color(red: 230/255, green: 174/255, blue: 37/255)) { EmptyView() }
                        } else { XiaodaGreeting() }
                        InspectionTemplateEditor(draft: $draft)
                    }
                }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.background(.white).clipped()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 12) {
                        if choosingMode {
                            Button(AppCopy.text("返回调整")) { if changeStep("sort") { choosingMode = false; proxy.scrollTo("setup.top", anchor: .top) } }
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(SetupStyle.purple)
                                .frame(minHeight: 50).accessibilityIdentifier("setup.back")
                        }
                        Button(AppCopy.text(choosingMode ? "选好啦" : "排好啦")) {
                            if choosingMode { finish() }
                            else if changeStep("mode") { choosingMode = true; proxy.scrollTo("setup.top", anchor: .top) }
                        }.buttonStyle(SetupButtonStyle()).accessibilityIdentifier("setup.next")
                    }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
                        .background(.white).overlay(alignment: .top) { Divider() }
                }
        }.onAppear { choosingMode = initialStep == "mode" }
    }
}

struct SetupButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .bold)).foregroundStyle(enabled ? .white : Color(red: 133/255, green: 139/255, blue: 154/255))
            .frame(maxWidth: .infinity).frame(minHeight: 50)
            .background(enabled ? Color(red: 82 / 255, green: 80 / 255, blue: 220 / 255) : Color(red: 229/255, green: 231/255, blue: 237/255), in: RoundedRectangle(cornerRadius: 14))
            .compositingGroup().shadow(color: enabled ? Color(red: 56 / 255, green: 54 / 255, blue: 179 / 255) : Color(red: 200/255, green: 203/255, blue: 213/255), radius: 0, y: configuration.isPressed ? 2 : 4)
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
