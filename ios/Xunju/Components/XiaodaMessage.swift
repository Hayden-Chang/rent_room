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
                }
                    .padding(.vertical, max(0, ((actionLayout ? 34 : (compact ? 15 : 16) * 1.65) - UIFont.systemFont(ofSize: compact ? 15 : 16).lineHeight) / 2))
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
                .accessibilityElement(children: .contain).accessibilityIdentifier("xiaoda.bubble")
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
    private func speech(_ value: String) -> XiaodaSpeechText {
        XiaodaSpeechText(attributedText: XiaodaSpeech.attributed(value, highlights: highlights.map { AppCopy.text($0) }, icons: icons,
            fontSize: compact ? 15 : 16, lineHeight: actionLayout ? 34 : (compact ? 15 : 16) * 1.65,
            centered: hero, highlightColor: UIColor(highlightColor)))
    }
}

// Match the mini-program's natural wrapping instead of balancing short paragraphs.
// Both the hidden full message and the typing overlay use the same width and renderer.
struct XiaodaSpeechText: UIViewRepresentable {
    let attributedText: NSAttributedString
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakStrategy = []
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) { label.attributedText = attributedText }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: ceil(uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
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
            Button { closing = true } label: {
                ZStack {
                    Capsule().frame(width: 2, height: 16).rotationEffect(.degrees(45))
                    Capsule().frame(width: 2, height: 16).rotationEffect(.degrees(-45))
                }.frame(width: 16, height: 16)
                    .foregroundStyle(Color(red: 114/255, green: 124/255, blue: 144/255))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).offset(x: 10, y: -12)
                .accessibilityLabel(AppCopy.text("关闭小搭")).accessibilityIdentifier("xiaoda.close")
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
    var swipeProgress: (CGFloat) -> Void = { _ in }
    var decoratedSpeech = false
    var adjustScroll: (CGFloat, UnitPoint) -> Void = { _, _ in }
    let next: () -> Void
    private var step: Int { guide["tutorial"].int }
    private var entry: JSONValue { guide["steps"].array.indices.contains(step - 1) ? guide["steps"].array[step - 1] : .null }
    var body: some View {
        GeometryReader { geometry in
            let rect = XiaodaTutorialLayout.spotlight(target, available: geometry.size)
            ZStack(alignment: .topLeading) {
                if let rect {
                    shade(width: geometry.size.width, height: max(0, rect.minY))
                    shade(width: geometry.size.width, height: max(0, geometry.size.height - rect.maxY)).offset(y: rect.maxY)
                    shade(width: max(0, rect.minX), height: rect.height).offset(y: rect.minY)
                    shade(width: max(0, geometry.size.width - rect.maxX), height: rect.height).offset(x: rect.maxX, y: rect.minY)
                    RoundedRectangle(cornerRadius: 12).strokeBorder(XiaodaTutorialLayout.accent, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY).allowsHitTesting(false)
                } else { shade(width: geometry.size.width, height: geometry.size.height) }
                if step == 3, let rect, let swipeCompleted {
                    XiaodaSwipeTarget(completed: swipeCompleted, progress: swipeProgress)
                        .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                }
                XiaodaTutorialCardLayout(target: rect) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 12) {
                            AppText("\(step) / 4").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(red: 112/255, green: 120/255, blue: 139/255))
                            HStack(spacing: 6) {
                                ForEach(1...4, id: \.self) { index in
                                    Capsule().fill(index <= step ? Color(red: 97/255, green: 89/255, blue: 232/255) : Color(red: 233/255, green: 234/255, blue: 242/255)).frame(height: 6)
                                }
                            }.accessibilityHidden(true)
                        }
                        AppText(entry["title"].string).font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Color(red: 48/255, green: 57/255, blue: 76/255))
                            .padding(.top, 12).padding(.bottom, 16).accessibilityIdentifier("coach.title")
                        XiaodaMessage(text: entry["text"].string, pose: entry["pose"].string,
                            highlights: decoratedSpeech ? entry["highlights"].array.map(\.string) : [],
                            icons: decoratedSpeech ? XiaodaSpeech.iconMap(entry["icons"]) : [:], actionLayout: decoratedSpeech && !XiaodaSpeech.iconMap(entry["icons"]).isEmpty) { EmptyView() }
                        if step != 3 {
                            Button(AppCopy.text(step == 4 ? "我会啦" : "知道啦"), action: next)
                                .buttonStyle(XJButtonStyle(primary: true)).padding(.top, 20).accessibilityIdentifier("coach.next")
                        }
                    }.padding(22).frame(width: max(0, geometry.size.width - 24), alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(red: 226/255, green: 229/255, blue: 236/255), lineWidth: 2))
                    .accessibilityElement(children: .contain).accessibilityIdentifier("coach.card")
                    .background {
                        GeometryReader { card in
                            let adjustment = XiaodaTutorialLayout.scrollAdjustment(target: target, cardHeight: card.size.height, available: geometry.size.height)
                            Color.clear.task(id: adjustment) {
                                if abs(adjustment) > 2,
                                   let anchor = XiaodaTutorialLayout.scrollAnchor(target: target, cardHeight: card.size.height, available: geometry.size.height) {
                                    adjustScroll(adjustment, anchor)
                                }
                            }
                        }
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
        }
    }
    private func shade(width: CGFloat, height: CGFloat) -> some View {
        Color(red: 27/255, green: 35/255, blue: 73/255).opacity(87/255).frame(width: width, height: height).contentShape(Rectangle()).onTapGesture {}
    }
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
