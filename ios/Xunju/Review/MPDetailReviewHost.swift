#if DEBUG
import SwiftUI

struct MPDetailReviewHost: View {
    let state: String
    let back: () -> Void
    @State private var tab = "清单"
    @State private var phase = "全部"
    @State private var query = ""
    @State private var filters: Set<String> = []
    @State private var showFilters = false
    @State private var coordinator = MPSwipeCoordinator()
    @State private var category = MPFieldState(expanded: true)
    @State private var window = MPFieldState(expanded: true)
    @State private var seal = MPFieldState(selected: ["是"])
    @State private var screen = MPFieldState()
    @State private var rent = MPFieldState(text: "3200")
    @State private var address = MPFieldState(text: "朝阳路18号")
    @State private var noteTarget = ""
    @State private var noteText = ""
    @State private var source = false
    @State private var editor = false
    @State private var decision = "继续比较"
    @State private var summaryNote = ""
    @State private var resolved = false
    @State private var filter: MediaFilter = .all
    @State private var media: [MPMediaItem] = []
    @State private var preview = ""
    @State private var mediaMenu = ""
    @State private var association = false
    @State private var associationQuery = ""
    @State private var costs = 0
    private var readonly: Bool { state == "readonly" }
    var body: some View {
        ZStack {
            MPDetailSurface(tab: $tab, readonly: readonly, mediaCount: media.count, issueCount: state == "empty" ? 0 : 3) {
                checklist
            } media: {
                MPMediaGallery(items: media, filter: $filter, readonly: readonly, preview: { preview = $0 },
                    caption: { id in noteTarget = id; noteText = media.first { $0.id == id }?.tile.caption ?? "" }, manage: { mediaMenu = $0 }, capture: { source = true })
            } issues: {
                MPIssuesSurface(count: state == "empty" ? 0 : 3, readonly: readonly, add: { editor = true }) {
                    if state != "empty" {
                        AutomaticIssueCard(category: "门窗") {
                            MPFieldRow(item: MPFieldItem(id: "issue-window", title: "窗户密封", options: ["是", "否"]), state: $seal, readonly: readonly,
                                coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                        }
                        ManualIssueCard(id: "one", title: "卧室窗框有水渍", note: "雨后再确认是否渗水", media: media.map(\.tile), resolved: resolved, readonly: readonly,
                            resolve: { resolved.toggle() }, open: { editor = true }, preview: { preview = $0.id })
                    }
                }
            } summary: {
                MPSummarySurface(decision: $decision, note: $summaryNote, readonly: readonly)
            }.accessibilityHidden(!noteTarget.isEmpty || source || !mediaMenu.isEmpty || association)
            if !noteTarget.isEmpty {
                MPNoteSheet(title: noteTarget == "seal" ? "窗户密封" : "影像备注", text: $noteText, readonly: readonly,
                    close: { noteTarget = "" }, save: {
                        if noteTarget == "seal" { seal.note = noteText }
                        else if let index = media.firstIndex(where: { $0.id == noteTarget }) { media[index].tile.caption = noteText }
                        noteTarget = ""
                    })
            }
            if source { MPSourceSheet(close: { source = false }, library: { source = false }, camera: { source = false }) }
            if !mediaMenu.isEmpty {
                MPActionMenu(title: "", actions: [
                    ("关联检查项", false, { association = true; mediaMenu = "" }),
                    ("取消关联", false, { mediaMenu = "" }),
                    ("移除影像", true, { media.removeAll { $0.id == mediaMenu }; mediaMenu = "" })
                ], close: { mediaMenu = "" })
            }
            if association { MPAssociationSheet(items: [("seal", "门窗 / 窗户密封"), ("screen", "门窗 / 纱窗")], query: $associationQuery, close: { association = false }, select: { _ in association = false }) }
        }.fullScreenCover(isPresented: Binding(get: { !preview.isEmpty }, set: { if !$0 { preview = "" } })) {
            MPMediaPreview(items: media, selected: $preview) { preview = "" }
        }.fullScreenCover(isPresented: $editor) {
            MPIssueReviewHost(state: readonly ? "readonly" : "", close: { editor = false })
        }.task {
            if media.isEmpty && state != "empty" {
                do { media = try MediaReviewFixtures.make().map { MPMediaItem(id: $0.id, tile: $0, duration: $0.kind == .video ? 12 : 0) } }
                catch { noteTarget = "fixture"; noteText = "评审影像未能加载：\(error.localizedDescription)" }
            }
            if ["media", "issues", "summary"].contains(state) { tab = state == "media" ? "影像" : state == "issues" ? "问题" : "总结" }
        }
    }
    private var checklist: some View {
        MPChecklistSurface(done: 86, total: 302, issues: 3, phase: $phase, query: $query, filters: $filters, showFilters: $showFilters, readonly: readonly, coordinator: coordinator, capture: { source = true }) {
            MPCard {
                VStack(spacing: 0) {
                    MPFieldRow(item: MPFieldItem(id: "category", title: "门窗", kind: .category, stats: "2 / 4"), state: $category, readonly: readonly, coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                    if category.expanded {
                        MPFieldRow(item: MPFieldItem(id: "window", title: "窗户", kind: .group, options: ["有", "无"], skippable: true), state: $window, readonly: readonly, coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                        if window.expanded && !window.skipped {
                            MPFieldRow(item: MPFieldItem(id: "seal", title: "窗户密封", options: ["是", "否"], photoRef: "A03"), state: $seal, readonly: readonly, coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                            FieldMediaStrip(items: media.map(\.tile), preview: { preview = $0.id }, all: { preview = media.first?.id ?? "" })
                            MPFieldRow(item: MPFieldItem(id: "screen", title: "纱窗", options: ["有", "无"]), state: $screen, readonly: readonly, coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                        }
                    }
                    MPFieldRow(item: MPFieldItem(id: "rent", title: "月租金", kind: .number), state: $rent, readonly: readonly, coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                    MPFieldRow(item: MPFieldItem(id: "address", title: "房源地址", kind: .text), state: $address, readonly: readonly, coordinator: coordinator, note: { editNote("seal") }, capture: { source = true })
                    ForEach(0..<costs, id: \.self) { index in Text("其他费用 \(index + 1)").font(.system(size: 14)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                    if !readonly {
                        Button { costs += 1; query = ""; filters = []; window.expanded = true }
                            label: { Text("＋").font(.system(size: 24)).foregroundStyle(Color(red: 141/255, green: 149/255, blue: 163/255)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                            .buttonStyle(.plain).frame(maxWidth: .infinity).accessibilityLabel("添加费用").accessibilityIdentifier("mp.cost.add")
                    }
                }
            }
        }
    }
    private func editNote(_ target: String) { coordinator.close(); noteTarget = target; noteText = seal.note }
}

struct MPIssueReviewHost: View {
    let state: String
    let close: () -> Void
    @State private var title = ""
    @State private var note = ""
    @State private var titleError = ""
    @State private var error = ""
    @State private var media: [MediaTile] = []
    @State private var source = false
    @State private var discard = false
    @State private var saving = false
    @State private var preview = ""
    var body: some View {
        ZStack {
            MPFrame(title: state == "readonly" ? "查看问题" : "新建问题", back: cancel) {
                MPIssueEditorSurface(title: $title, note: $note, media: media, readonly: state == "readonly", busy: saving, error: error, titleError: titleError,
                preview: { preview = $0.id }, remove: { item in media.removeAll { $0.id == item.id } }, add: { source = true },
                cancel: cancel,
                save: { if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { titleError = "请填写问题标题" } else { saving = true } })
            } footer: { EmptyView() }
                .accessibilityHidden(source || discard).allowsHitTesting(!source && !discard)
            if source { MPSourceSheet(close: { source = false }, library: { source = false }, camera: { source = false }) }
            if discard { MPConfirmation(title: "放弃修改？", message: "尚未保存的文字和新增影像将被放弃。", confirmTitle: "放弃", destructive: true, cancelTitle: "继续编辑", cancel: { discard = false }, confirm: close) }
        }.fullScreenCover(isPresented: Binding(get: { !preview.isEmpty }, set: { if !$0 { preview = "" } })) {
            MPMediaPreview(items: media.map { MPMediaItem(id: $0.id, tile: $0) }, selected: $preview) { preview = "" }
        }.task {
            if state == "readonly" || state == "media" {
                title = "卧室窗框有水渍"; note = "雨后再确认是否渗水"
                do { media = try MediaReviewFixtures.make() } catch { self.error = error.localizedDescription }
            }
        }
        .onChange(of: title) { titleError = ""; error = "" }
    }
    private func cancel() {
        if state == "readonly" || (title.isEmpty && note.isEmpty && media.isEmpty) { close() }
        else { discard = true }
    }
}
#endif
