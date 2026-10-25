import SwiftUI

struct XiaodaMessage<Actions: View>: View {
    let text: String
    var pose = "think"
    var compact = true
    @ViewBuilder var actions: Actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = ""
    @State private var completed = false
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("xiaoda-" + pose).resizable().scaledToFit()
                .frame(width: compact ? 72 : 88, height: compact ? 84 : 104).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(text).hidden().overlay(alignment: .topLeading) {
                    Text(shown).frame(maxWidth: .infinity, alignment: .leading)
                }.font(.system(size: compact ? 15 : 16)).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore).accessibilityLabel(text)
                    .accessibilityValue(completed ? "完整显示" : "正在显示").accessibilityIdentifier("xiaoda.message")
                    .contentShape(Rectangle()).onTapGesture { completed = true; shown = text }
                actions
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color(red: 52/255, green: 59/255, blue: 77/255))
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(XJTheme.line, lineWidth: 2))
        }.task(id: text) {
            completed = false; shown = ""
            if reduceMotion { shown = text; completed = true; return }
            for character in text {
                if Task.isCancelled || completed { return }
                shown.append(character)
                do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
            }
            completed = true
        }
    }
}

struct XiaodaGuidanceCard: View {
    let prompt: JSONValue
    let action: (String) -> Void
    @State private var closing = false
    var body: some View {
        XiaodaMessage(text: prompt["text"].string, pose: prompt["kind"].string == "return" ? "bye" : "think") {
            HStack(spacing: 8) {
                if prompt["kind"].string != "intro" {
                    Button(prompt["kind"].string == "phase" ? "看看其他房子" : prompt["kind"].string == "return" ? "先等等" : "再等等") {
                        action(prompt["kind"].string == "phase" ? "other" : "later")
                    }.font(.system(size: 13)).accessibilityIdentifier("xiaoda.later")
                }
                Button(prompt["kind"].string == "return" ? "返回房源列表" : "去填写") { action("accept") }
                    .buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("xiaoda.accept")
            }
        }.padding(.top, 24).overlay(alignment: .topTrailing) {
            Button { closing = true } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .foregroundStyle(XJTheme.muted).accessibilityLabel("关闭小搭").accessibilityIdentifier("xiaoda.close")
        }.confirmationDialog("关闭小搭", isPresented: $closing, titleVisibility: .visible) {
            Button("当前房源关闭") { action("house") }
            Button("今天关闭") { action("day") }
            Button("永久关闭") { action("permanent") }
        }.accessibilityIdentifier("xiaoda.guide")
    }
}

struct XiaodaTutorialOverlay: View {
    let guide: JSONValue
    let target: CGRect?
    let next: () -> Void
    @State private var measuredHeight: CGFloat = 330
    private var step: Int { guide["tutorial"].int }
    private var entry: JSONValue { guide["steps"].array.indices.contains(step - 1) ? guide["steps"].array[step - 1] : .null }
    var body: some View {
        GeometryReader { geometry in
            let rect = target?.insetBy(dx: -4, dy: -4)
            let top = CoachPlacement.cardTop(target: rect, height: measuredHeight, available: geometry.size.height)
            ZStack(alignment: .topLeading) {
                if let rect {
                    shade(width: geometry.size.width, height: max(0, rect.minY))
                    shade(width: geometry.size.width, height: max(0, geometry.size.height - rect.maxY)).offset(y: rect.maxY)
                    shade(width: max(0, rect.minX), height: rect.height).offset(y: rect.minY)
                    shade(width: max(0, geometry.size.width - rect.maxX), height: rect.height).offset(x: rect.maxX, y: rect.minY)
                    RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY).allowsHitTesting(false)
                } else { shade(width: geometry.size.width, height: geometry.size.height) }
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(step) / 4").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    Text(entry["title"].string).font(.system(size: 17, weight: .semibold)).accessibilityIdentifier("coach.title")
                    XiaodaMessage(text: entry["text"].string, pose: entry["pose"].string) { EmptyView() }
                    if step != 3 {
                        Button(step == 4 ? "我会啦" : "知道啦", action: next)
                            .buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("coach.next")
                    }
                }.padding(16).frame(width: max(0, geometry.size.width - 32))
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .background(GeometryReader { proxy in Color.clear.preference(key: XiaodaTutorialHeight.self, value: proxy.size.height) })
                    .offset(x: 16, y: top)
            }.onPreferenceChange(XiaodaTutorialHeight.self) { measuredHeight = $0 }
        }
    }
    private func shade(width: CGFloat, height: CGFloat) -> some View {
        XJTheme.ink.opacity(0.6).frame(width: width, height: height).contentShape(Rectangle()).onTapGesture {}
    }
}

private struct XiaodaTutorialHeight: PreferenceKey {
    static let defaultValue: CGFloat = 330
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct InspectionInteractionKey: EnvironmentKey {
    static let defaultValue: (String, Bool?) -> Void = { _, _ in }
}
extension EnvironmentValues {
    var inspectionInteraction: (String, Bool?) -> Void {
        get { self[InspectionInteractionKey.self] }
        set { self[InspectionInteractionKey.self] = newValue }
    }
}
