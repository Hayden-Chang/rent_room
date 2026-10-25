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

private enum SetupStyle {
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
            Text("你好呀！我是小搭。\n先让我了解一下你的偏好，\n给你最关心的事情排个序吧！")
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
    @State private var frames: [String: CGRect] = [:]
    @GestureState private var drag: TemplateDrag?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(draft.order, id: \.self) { title in
                    HStack(spacing: 0) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20)).foregroundStyle(Color.gray)
                            .frame(width: 54, height: 64).contentShape(Rectangle())
                            .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .named("template.list"))
                                .updating($drag) { value, state, _ in
                                    state = TemplateDrag(title: title, translation: value.translation.height)
                                }.onEnded { value in
                                    let target = destination(TemplateDrag(title: title, translation: value.translation.height))
                                    withAnimation(.easeInOut(duration: 0.18)) { draft.move(title, to: target) }
                                })
                            .accessibilityLabel("拖动\(title)")
                            .accessibilityIdentifier("setup.drag.\(title)")
                            .accessibilityAction(named: "上移") { move(title, offset: -1) }
                            .accessibilityAction(named: "下移") { move(title, offset: 1) }
                        Text(title).font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(draft.disabled.contains(title) ? Color.gray : SetupStyle.ink)
                            .strikethrough(draft.disabled.contains(title))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                            .accessibilityIdentifier("setup.title.\(title)")
                        Button {
                            error = draft.toggle(title) ?? ""
                        } label: {
                            Image(systemName: draft.disabled.contains(title) ? "arrow.uturn.backward" : "trash")
                                .font(.system(size: 21)).frame(width: 48, height: 48)
                                .foregroundStyle(draft.disabled.contains(title) ? Color.gray : XJTheme.danger)
                        }.buttonStyle(.plain).padding(.horizontal, 8)
                            .accessibilityLabel("\(draft.disabled.contains(title) ? "恢复" : "停用")\(title)")
                            .accessibilityIdentifier("setup.toggle.\(title)")
                    }
                    .frame(minHeight: 64)
                    .background(drag?.title == title ? XJTheme.soft : draft.disabled.contains(title) ? XJTheme.background : .white)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: TemplateFrames.self, value: [title: geometry.frame(in: .named("template.list"))])
                    })
                    .offset(y: offset(title)).zIndex(drag?.title == title ? 1 : 0)
                    if title != draft.order.last { Divider().overlay(SetupStyle.border) }
                }
            }.coordinateSpace(name: "template.list")
                .onPreferenceChange(TemplateFrames.self) { if drag == nil { frames = $0 } }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(SetupStyle.border, lineWidth: 2))
            if !error.isEmpty {
                Text(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12)
                    .accessibilityIdentifier("setup.error")
            }
        }
    }

    private func move(_ title: String, offset: Int) {
        guard let index = draft.order.firstIndex(of: title), draft.order.indices.contains(index + offset) else { return }
        draft.move(title, to: draft.order[index + offset])
    }

    private func destination(_ drag: TemplateDrag) -> String {
        guard let start = frames[drag.title] else { return drag.title }
        let center = start.midY + drag.translation
        return draft.order.min { abs((frames[$0]?.midY ?? center) - center) < abs((frames[$1]?.midY ?? center) - center) } ?? drag.title
    }

    private func offset(_ title: String) -> CGFloat {
        guard let drag, let from = draft.order.firstIndex(of: drag.title),
              let to = draft.order.firstIndex(of: destination(drag)), let index = draft.order.firstIndex(of: title) else { return 0 }
        if title == drag.title { return drag.translation }
        let height = (frames[drag.title]?.height ?? 64) + 1
        if from < to && index > from && index <= to { return -height }
        if from > to && index >= to && index < from { return height }
        return 0
    }
}

private struct TemplateDrag: Equatable { let title: String; let translation: CGFloat }
private struct TemplateFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, next in next }) }
}

struct InspectionModeChoice: View {
    @Binding var selection: InspectionMode
    private let details = ["外卖能上楼", "超市 / 便利店", "附近有菜市场", "附近有餐饮", "附近有药店", "附近有医院", "附近有快递"]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(InspectionMode.allCases, id: \.self) { mode in
                VStack(alignment: .leading, spacing: 12) {
                    Button { selection = mode } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selection == mode ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 20)).foregroundStyle(selection == mode ? SetupStyle.purple : Color.gray)
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) { title(mode); subtitle(mode) }
                                VStack(alignment: .leading, spacing: 4) { title(mode); subtitle(mode) }
                            }
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("setup.mode.\(mode.rawValue)")
                        .accessibilityLabel(mode.title).accessibilityValue(selection == mode ? "已选择" : "未选择")
                        .accessibilityAddTraits(selection == mode ? .isSelected : [])
                    VStack(alignment: .leading, spacing: 8) {
                        Text("示例").font(.system(size: 12, weight: .semibold)).foregroundStyle(XJTheme.muted)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(XJTheme.background, in: RoundedRectangle(cornerRadius: 5))
                        if mode == .simple { simpleExample } else { detailedExample }
                    }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                }.padding(14)
                    .background(selection == mode ? SetupStyle.soft : .white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selection == mode ? SetupStyle.purple : SetupStyle.border, lineWidth: 2))
            }
        }
    }

    private func title(_ mode: InspectionMode) -> some View {
        Text(mode.title).font(.system(size: 18, weight: .bold)).foregroundStyle(selection == mode ? SetupStyle.purple : SetupStyle.ink)
    }
    private func subtitle(_ mode: InspectionMode) -> some View {
        Text(mode.detail).font(.system(size: 14)).foregroundStyle(XJTheme.muted)
    }
    private var simpleExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("生活配套方便").font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 8)
                answer("是", problem: false); answer("否", problem: true)
            }
            Text("看看附近的超市、菜市场、餐饮、药店、医院和快递，以及外卖能否上楼。")
                .font(.system(size: 14)).lineSpacing(5).foregroundStyle(XJTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("备注").foregroundStyle(XJTheme.muted)
                Text("附近没有菜市场").foregroundStyle(XJTheme.danger)
                Spacer(minLength: 0)
            }.font(.system(size: 14)).padding(10).background(XJTheme.dangerBackground, in: RoundedRectangle(cornerRadius: 8))
        }.fixedSize(horizontal: false, vertical: true)
    }
    private var detailedExample: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("生活配套").font(.system(size: 16, weight: .semibold)).padding(.bottom, 6)
            ForEach(details, id: \.self) { label in
                let problem = label == "附近有菜市场"
                HStack {
                    Text(label).font(.system(size: 14)).foregroundStyle(problem ? XJTheme.danger : SetupStyle.ink)
                    Spacer(); answer(problem ? "否" : "是", problem: problem)
                }.padding(.horizontal, 6).frame(minHeight: 38)
                    .background(problem ? XJTheme.dangerBackground : .clear, in: RoundedRectangle(cornerRadius: 6))
                if label != details.last { Divider() }
            }
        }
    }
    private func answer(_ text: String, problem: Bool) -> some View {
        Text(text).font(.system(size: 14, weight: problem ? .semibold : .regular))
            .foregroundStyle(problem ? XJTheme.danger : XJTheme.muted)
            .frame(width: 32, height: 28)
            .background(problem ? XJTheme.dangerBackground : XJTheme.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct InspectionSetupSurface: View {
    @Binding var draft: InspectionTemplateDraft
    @Binding var mode: InspectionMode
    @State private var choosingMode = false
    var finish: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 6) {
                        Capsule().fill(SetupStyle.purple).frame(height: 8)
                        Capsule().fill(choosingMode ? SetupStyle.purple : SetupStyle.border).frame(height: 8)
                        Text(choosingMode ? "2 / 2" : "1 / 2").font(.system(size: 12, weight: .semibold)).padding(.leading, 10)
                    }.foregroundStyle(XJTheme.muted).id("setup.top")
                    VStack(alignment: .leading, spacing: 8) {
                        if !choosingMode {
                            Text("和小搭一起，准备看房").font(.system(size: 12, weight: .semibold)).foregroundStyle(XJTheme.muted)
                        }
                        Text(choosingMode ? "选一种记录方式" : "定制你的看房清单")
                            .font(.system(size: 24, weight: .bold)).foregroundStyle(SetupStyle.ink)
                    }
                    if choosingMode { InspectionModeChoice(selection: $mode) }
                    else { XiaodaGreeting(); InspectionTemplateEditor(draft: $draft) }
                }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.background(.white).clipped()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 12) {
                        if choosingMode {
                            Button("返回调整") { choosingMode = false; proxy.scrollTo("setup.top", anchor: .top) }
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(SetupStyle.purple)
                                .frame(minHeight: 50).accessibilityIdentifier("setup.back")
                        }
                        Button(choosingMode ? "选好啦" : "排好啦") {
                            if choosingMode { finish() }
                            else { choosingMode = true; proxy.scrollTo("setup.top", anchor: .top) }
                        }.buttonStyle(SetupButtonStyle()).accessibilityIdentifier("setup.next")
                    }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
                        .background(.white).overlay(alignment: .top) { Divider() }
                }
        }
    }
}

private struct SetupButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(minHeight: 50)
            .background(Color(red: 82 / 255, green: 80 / 255, blue: 220 / 255), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color(red: 56 / 255, green: 54 / 255, blue: 179 / 255), radius: 0, y: configuration.isPressed ? 2 : 4)
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
