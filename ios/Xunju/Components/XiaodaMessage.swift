import SwiftUI

struct XiaodaMessage<Actions: View>: View {
    let text: String
    var pose = "think"
    var compact = true
    var hero = false
    var highlights: [String] = []
    var icons: [Character: String] = [:]
    var highlightColor: Color = Color(red: 184/255, green: 134/255, blue: 11/255)
    var actionLayout = false
    @ViewBuilder var actions: Actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = ""
    @State private var completed = false
    private var localizedText: String { AppCopy.text(text, translatingArguments: true) }
    var body: some View {
        let layout = hero ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(alignment: .center, spacing: compact ? 12 : 14))
        layout {
            if !hero { character }
            VStack(alignment: .leading, spacing: 12) {
                speech(localizedText).frame(maxWidth: .infinity, alignment: hero ? .center : .leading).hidden().overlay(alignment: .topLeading) {
                    speech(shown).frame(maxWidth: .infinity, alignment: hero ? .center : .leading)
                }.font(.system(size: compact ? 15 : 16))
                    .lineSpacing((actionLayout ? 34 : (compact ? 15 : 16) * 1.65) - UIFont.systemFont(ofSize: compact ? 15 : 16).lineHeight)
                    .padding(.vertical, max(0, ((actionLayout ? 34 : (compact ? 15 : 16) * 1.65) - UIFont.systemFont(ofSize: compact ? 15 : 16).lineHeight) / 2))
                    .multilineTextAlignment(hero ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore).accessibilityLabel(localizedText)
                    .accessibilityValue(AppCopy.text(completed ? "完整显示" : "正在显示")).accessibilityIdentifier("xiaoda.message")
                    .contentShape(Rectangle()).onTapGesture { completed = true; shown = localizedText }
                actions
            }.padding(.horizontal, (compact ? 14 : 16) + 2).padding(.vertical, (actionLayout ? 18 : compact ? 14 : 16) + 2)
                .frame(maxWidth: .infinity, alignment: hero ? .center : .leading)
                .foregroundStyle(Color(red: 52/255, green: 59/255, blue: 77/255))
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(red: 226/255, green: 229/255, blue: 236/255), lineWidth: 2))
                .overlay(alignment: hero ? .bottom : .leading) {
                    XiaodaBubbleTail().fill(.white)
                        .overlay(XiaodaBubbleTail().stroke(Color(red: 226/255, green: 229/255, blue: 236/255), lineWidth: 2))
                        .frame(width: 10, height: 18).rotationEffect(.degrees(hero ? -90 : 0))
                        .offset(x: hero ? 0 : -7, y: hero ? 12 : 0).allowsHitTesting(false)
                }
            if hero { character }
        }.frame(minHeight: hero ? 0 : 108).task(id: localizedText) {
            completed = false; shown = ""
            if reduceMotion { shown = localizedText; completed = true; return }
            for character in localizedText {
                if Task.isCancelled || completed { return }
                shown.append(character)
                do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
            }
            completed = true
        }
    }
    private var character: some View {
        Image("xiaoda-" + pose).resizable().scaledToFit()
            .frame(width: hero ? 144 : compact ? 72 : 88, height: hero ? 156 : compact ? 84 : 104).accessibilityHidden(true)
    }
    private func speech(_ value: String) -> Text {
        XiaodaSpeech.parts(value, highlights: highlights.map { AppCopy.text($0) }, icons: icons).reduce(AppText("")) { result, part in
            if let icon = part.icon {
                if icon == "handle" { return result + Text(Image(systemName: "line.3.horizontal")).foregroundColor(.gray) }
                if icon == "trash" { return result + Text(Image(systemName: "trash")).foregroundColor(XJTheme.danger) }
                if let image = XiaodaSpeech.actionImage(icon) { return result + AppText(" ") + Text(Image(uiImage: image)).baselineOffset(-4) + AppText(" ") }
            }
            return result + (part.emphasis ? Text(verbatim: part.text).bold().foregroundColor(highlightColor) : Text(verbatim: part.text))
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
                    Button(AppCopy.text(prompt["kind"].string == "phase" ? "看看其他房子" : prompt["kind"].string == "return" ? "先等等" : "再等等")) {
                        action(prompt["kind"].string == "phase" ? "other" : "later")
                    }.font(.system(size: 13)).accessibilityIdentifier("xiaoda.later")
                }
                Button(AppCopy.text(prompt["kind"].string == "return" ? "返回房源列表" : "去填写")) { action("accept") }
                    .buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("xiaoda.accept")
            }
        }.padding(.top, 24).overlay(alignment: .topTrailing) {
            Button { closing = true } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .foregroundStyle(XJTheme.muted).accessibilityLabel(AppCopy.text("关闭小搭")).accessibilityIdentifier("xiaoda.close")
        }.confirmationDialog(AppCopy.text("关闭小搭"), isPresented: $closing, titleVisibility: .visible) {
            Button(AppCopy.text("当前房源关闭")) { action("house") }
            Button(AppCopy.text("今天关闭")) { action("day") }
            Button(AppCopy.text("永久关闭")) { action("permanent") }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("xiaoda.guide")
    }
}

struct XiaodaTutorialOverlay: View {
    let guide: JSONValue
    let target: CGRect?
    var swipeCompleted: (() -> Void)? = nil
    var decoratedSpeech = false
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
                if step == 3, let rect, let swipeCompleted {
                    XiaodaSwipeTarget(completed: swipeCompleted)
                        .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                }
                VStack(alignment: .leading, spacing: 12) {
                    AppText("\(step) / 4").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    AppText(entry["title"].string).font(.system(size: 17, weight: .semibold)).accessibilityIdentifier("coach.title")
                    XiaodaMessage(text: entry["text"].string, pose: entry["pose"].string,
                        highlights: decoratedSpeech ? entry["highlights"].array.map(\.string) : [],
                        icons: decoratedSpeech ? XiaodaSpeech.iconMap(entry["icons"]) : [:], actionLayout: decoratedSpeech && !XiaodaSpeech.iconMap(entry["icons"]).isEmpty) { EmptyView() }
                    if step != 3 {
                        Button(AppCopy.text(step == 4 ? "我会啦" : "知道啦"), action: next)
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

private struct XiaodaBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
    }
}
