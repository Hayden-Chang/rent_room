#if DEBUG
import SwiftUI

// This host changes only disposable fixture state. It does not import user
// photos, request camera access, or write a house/issue through NativeStore.
struct MediaComponentReviewHost: View {
    let surface: ReviewSurface
    private let fixtures: [MediaTile]
    private let fixtureError: String
    @State private var items: [MediaTile]
    @State private var filter: MediaFilter = .all
    @State private var preview: MediaTile?
    @State private var caption: MediaTile?
    @State private var title = ""
    @State private var note = ""
    @State private var titleError = ""
    @State private var error = ""
    @State private var readonly = false
    @State private var event = ""
    @State private var expanded = true
    @State private var groupExpanded = true
    @State private var skipped = false
    @State private var value = "正常"
    @State private var categoryFlagged = false
    @State private var groupFlagged = false
    @State private var activeRow: String?
    @State private var selecting = false
    @State private var saving = false

    init(surface: ReviewSurface) {
        self.surface = surface
        do {
            let values = try MediaReviewFixtures.make()
            fixtures = values; fixtureError = ""
            _items = State(initialValue: surface == .media ? values : [])
        } catch {
            fixtures = []; fixtureError = "评审夹具创建失败：\(error.localizedDescription)"
            _items = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !fixtureError.isEmpty { Text(fixtureError).accessibilityIdentifier("review.fixtureError") }
                else if surface == .media { gallery }
                else if surface == .issueMedia { issue }
                else { headings }
            }.background(XJTheme.background)
                .navigationTitle(surface == .media ? "影像组件" : surface == .issueMedia ? "新建问题" : "分类与分组组件")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if surface == .issueMedia {
                        ToolbarItem(placement: .topBarLeading) {
                            Menu("评审状态") {
                                Button("选取中") { selecting = true; saving = false }
                                Button("保存中") { selecting = false; saving = true }
                                Button("恢复编辑") { selecting = false; saving = false }
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if surface == .media {
                            Button(items.isEmpty ? "恢复影像" : "空状态") { items = items.isEmpty ? fixtures : [] }
                                .accessibilityIdentifier("review.mediaEmpty")
                        } else {
                            Button(readonly ? "编辑态" : "只读态") { readonly.toggle() }
                                .accessibilityIdentifier("review.readonly")
                        }
                    }
                }
                .sheet(item: $preview) { item in
                    NavigationStack {
                        Group {
                            if item.kind == .video { InlineMediaVideo(url: item.url) }
                            else if let url = item.url, let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("review.mediaImage")
                            }
                        }.padding(16).navigationTitle("影像预览").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { preview = nil }.accessibilityIdentifier("review.previewClose")
                            } }
                    }
                }
                .sheet(item: $caption) { item in
                    NoteEditor(title: "影像备注", text: item.caption) { text in
                        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index].caption = text }
                    }
                }
        }.tint(XJTheme.primary)
    }

    private var gallery: some View {
        ScrollView {
            VStack(spacing: 16) {
                MediaGallerySurface(items: items, filter: $filter, preview: { preview = $0 }, caption: { caption = $0 })
                eventLabel
            }.padding(16)
        }.safeAreaInset(edge: .bottom) {
            Button("拍照或录视频") { event = "已触发添加影像；评审不会打开相册或相机" }
                .buttonStyle(XJButtonStyle(primary: true)).padding(16).accessibilityIdentifier("review.mediaAdd")
        }
    }

    private var issue: some View {
        VStack(spacing: 0) {
            if !event.isEmpty { eventLabel.padding(8) }
            IssueEditorSurface(title: $title, note: $note, media: items, titleError: $titleError, error: $error,
                               readonly: readonly, selecting: selecting, saving: saving, dirty: !title.isEmpty || !note.isEmpty || !items.isEmpty,
                               addMedia: { items = fixtures; error = ""; event = "" },
                               removeMedia: { item in items.removeAll { $0.id == item.id }; error = "" },
                               preview: { preview = $0 }, cancel: {
                if readonly { event = "已触发返回" }
                else { title = ""; note = ""; items = []; titleError = ""; error = ""; event = "已放弃未保存的修改" }
            }, save: {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { titleError = "请填写问题标题" }
                else { titleError = ""; error = "保存失败，请重试。文字和影像仍保留在本页。" }
            })
        }
    }

    private var headings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                XJCard {
                    VStack(spacing: 0) {
                        ChecklistHeadingRow(id: "category", title: "墙面地面与门窗", kind: .category,
                            done: value.isEmpty ? 0 : 1, total: 6, issues: (categoryFlagged ? 1 : 0) + (groupFlagged ? 1 : 0),
                            readonly: readonly, noteText: "重点确认窗框渗水痕迹。\n雨后再看一次，拍照保留细节。",
                            expanded: $expanded, skipped: .constant(false), value: .constant(""), flagged: $categoryFlagged, activeRow: $activeRow,
                            note: { event = "已触发分类备注" }, capture: { event = "已触发分类拍摄" })
                        if expanded {
                            ChecklistHeadingRow(id: "group", title: "窗户", done: value.isEmpty ? 0 : 1, total: 2,
                                issues: groupFlagged ? 1 : 0, options: ["正常", "有问题", "没有"], choiceLabels: ["正常": "是", "有问题": "否"], skippable: true, readonly: readonly,
                                noteText: "卧室窗户检查密封条，客厅窗户确认开合。",
                                expanded: $groupExpanded, skipped: $skipped, value: $value, flagged: $groupFlagged, activeRow: $activeRow,
                                note: { event = "已触发分组备注" }, capture: { event = "已触发分组拍摄" })
                            if groupExpanded && !skipped {
                                InspectionChoiceRow(title: "纱窗正常", options: ["是", "否", "没有"], value: .constant("是"),
                                                    flagged: .constant(false), readonly: readonly, note: {}, capture: {})
                            }
                        }
                    }
                }
                eventLabel
            }.padding(16)
        }
    }
    private var eventLabel: some View {
        Text(event).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
            .accessibilityIdentifier("review.mediaEvent")
    }
}
#endif
