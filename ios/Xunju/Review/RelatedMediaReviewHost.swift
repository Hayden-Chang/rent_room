#if DEBUG
import SwiftUI

// Isolated callbacks only; this host never imports or commits a house record.
struct RelatedMediaReviewHost: View {
    let surface: ReviewSurface
    private let media: [MediaTile]
    private let fixtureError: String
    @State private var readonly = false
    @State private var resolved = false
    @State private var opens = 0
    @State private var preview: MediaTile?
    @State private var all = false
    @State private var filter: MediaFilter = .all
    @State private var value = "有问题"
    @State private var flagged = true
    @State private var fee = "150"
    @State private var note = "雨后再确认窗框"
    @State private var editingNote = false
    @State private var event = ""

    init(surface: ReviewSurface) {
        self.surface = surface
        do { media = try MediaReviewFixtures.make(); fixtureError = "" }
        catch { media = []; fixtureError = error.localizedDescription }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !fixtureError.isEmpty { Text(fixtureError).accessibilityIdentifier("review.fixtureError") }
                    else if surface == .issueCards { cards }
                    else { fields }
                    Text("打开问题回调 \(opens) 次 · \(event)").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("review.relatedEvent")
                }.padding(16)
            }.background(XJTheme.background).navigationTitle(surface == .issueCards ? "问题卡片组件" : "关联影像与自动问题")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button(readonly ? "编辑态" : "只读态") { readonly.toggle() }.accessibilityIdentifier("review.readonly") }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
                }
                .sheet(item: $preview) { item in
                    NavigationStack {
                        Group {
                            if item.kind == .video { InlineMediaVideo(url: item.url) }
                            else if let url = item.url, let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("review.relatedImage")
                            }
                        }.padding(16).navigationTitle("影像预览").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { preview = nil }.accessibilityIdentifier("review.previewClose") } }
                    }
                }
                .sheet(isPresented: $all) {
                    NavigationStack {
                        ScrollView { MediaGallerySurface(items: relatedMedia, filter: $filter, readonly: readonly,
                            preview: { event = "预览关联影像 \($0.id)" }, caption: { _ in event = "备注回调" }).padding(16) }
                            .navigationTitle("全部关联影像").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { all = false }.accessibilityIdentifier("review.allClose") } }
                    }
                }
                .sheet(isPresented: $editingNote) { NoteEditor(title: "纱窗正常 · 备注", text: note, readonly: readonly) { note = $0 } }
        }.tint(XJTheme.primary)
    }
    private var cards: some View {
        VStack(spacing: 16) {
            ManualIssueCard(id: "mixed", title: "卧室窗框渗水，需要确认维修时间与修复后的验收安排", note: "雨后窗框有水渍。\n请房东确认修复时间，并保留现场影像。", media: media,
                resolved: resolved, readonly: readonly, resolve: { resolved.toggle() }, open: { opens += 1 }, preview: { preview = $0 })
            ManualIssueCard(id: "empty", title: "门锁钥匙待补齐", note: "", media: [], resolved: true, readonly: readonly,
                resolve: { event = "切换无影像问题" }, open: { opens += 1 }, preview: { preview = $0 })
        }
    }
    private var relatedMedia: [MediaTile] { media.count == 4 ? [media[0], media[3], media[1], media[2]] : media }
    private var fields: some View {
        VStack(spacing: 16) {
            AutomaticIssueCard(category: "门窗") {
                InspectionChoiceRow(title: "纱窗正常", options: ["正常", "有问题", "没有"], choiceLabels: ["正常": "是", "有问题": "否"],
                    value: $value, flagged: $flagged, readonly: readonly, note: { editingNote = true }, capture: { event = "触发检查项拍摄" })
                    .accessibilityIdentifier("review.automaticChoice")
                Button(note) { editingNote = true }.font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    .accessibilityIdentifier("review.automaticNote")
                FieldMediaStrip(items: relatedMedia, preview: { preview = $0 }, all: { all = true })
            }
            AutomaticIssueCard(category: "周边与小区") {
                AnswerInput(field: .object(["id": .string("relatedFee"), "label": .string("停车费（元/月）"), "type": .string("n")]),
                    text: $fee, otherText: .constant(""), readonly: readonly, showsKeyboardToolbar: false,
                    choose: { _ in }, action: { event = $0 })
            }
        }
    }
}
#endif
