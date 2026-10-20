import SwiftUI

private struct IssueSelection: Identifiable { let id: String; let isNew: Bool }
struct IssuesPage: View {
    let workspace: AppWorkspace
    let id: String
    @State private var automatic: [JSONValue] = []
    @State private var selection: IssueSelection?
    private var readonly: Bool { workspace.store.house(id)["archived"].bool }
    private var manual: [JSONValue] { workspace.store.house(id)["issues"].array }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SaveBanner(workspace: workspace)
                Text("需要关注 · \(workspace.store.houses.first { $0.id == id }?.stats.issues ?? 0)").font(.system(size: 14))
                if automatic.isEmpty && manual.isEmpty {
                    VStack(spacing: 12) {
                        Text("目前没有标记的问题").font(.system(size: 16, weight: .semibold))
                        Text("未检查的项目仍需继续查看。").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.top, 40)
                }
                ForEach(automatic, id: \.id) { field in
                    XJCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(field["category"].string).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                            Text(field["label"].string).font(.system(size: 14, weight: .medium))
                            Text(field["display"].string).font(.system(size: 13)).foregroundStyle(XJTheme.danger)
                            if !field["note"].string.isEmpty { Text(field["note"].string).font(.system(size: 13)) }
                            if !readonly { Button("取消问题标记") {
                                workspace.perform { try workspace.store.answer(id, field: field.id, property: "issueFlag", value: .bool(false)) }
                            }.font(.system(size: 13)) }
                        }
                    }
                }
                ForEach(manual, id: \.id) { issue in
                    XJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button(issue["title"].string) { selection = IssueSelection(id: issue.id, isNew: false) }
                                    .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                                Button(issue["resolved"].bool ? "已解决" : "待跟进") {
                                    workspace.perform { try workspace.store.call("resolveIssue", ["id": .string(id), "issueId": .string(issue.id)]) }
                                }.font(.system(size: 13)).disabled(readonly)
                            }
                            if !issue["note"].string.isEmpty { Text(issue["note"].string).font(.system(size: 13)) }
                            Text(readonly ? "查看详情 ›" : "查看 / 编辑 ›").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        }
                    }
                }
            }.padding(16)
        }.safeAreaInset(edge: .bottom) {
            if !readonly { Button("新建问题") { selection = IssueSelection(id: "i" + UUID().uuidString.replacingOccurrences(of: "-", with: ""), isNew: true) }
                .buttonStyle(XJButtonStyle(primary: true)).padding(16).accessibilityIdentifier("issue.add") }
        }.onAppear(perform: refresh).onChange(of: workspace.store.status.revision) { _, _ in refresh() }
            .sheet(item: $selection) { selection in IssueEditor(workspace: workspace, houseID: id, issueID: selection.id, isNew: selection.isNew) }
    }
    private func refresh() { workspace.perform { automatic = try workspace.store.call("issues", ["id": .string(id)])["automatic"].array } }
}

private struct IssueEditor: View {
    let workspace: AppWorkspace
    let isNew: Bool
    @State private var draft: IssueDraft
    @State private var picking = false
    @State private var preview: MediaTile?
    @Environment(\.dismiss) private var dismiss

    init(workspace: AppWorkspace, houseID: String, issueID: String, isNew: Bool) {
        self.workspace = workspace; self.isNew = isNew
        let store = workspace.store
        _draft = State(initialValue: IssueDraft(store: store, houseID: houseID, issueID: issueID, isNew: isNew,
                                               isCurrent: { workspace.store === store }))
    }
    var body: some View {
        NavigationStack {
            IssueEditorSurface(title: $draft.title, note: $draft.note,
                media: draft.media.map { mediaTile($0, store: draft.store) }, titleError: $draft.titleError, error: $draft.error,
                readonly: draft.readonly, selecting: picking, saving: draft.saving, dirty: draft.dirty,
                addMedia: { picking = true },
                removeMedia: { tile in if let item = draft.media.first(where: { $0.id == tile.id }) { draft.remove(item) } },
                preview: { preview = $0 }, cancel: { draft.discard(); dismiss() }, save: { if draft.save() { dismiss() } })
                .navigationTitle(isNew ? "新建问题" : "问题详情").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(draft.dirty || picking || draft.saving)
                .sheet(isPresented: $picking) {
                    MediaPickerSheet(workspace: workspace, houseID: draft.houseID, stage: { try draft.addImported($0) })
                }
                .sheet(item: $preview) { item in
                    NavigationStack {
                        Group {
                            if item.kind == .video { InlineMediaVideo(url: item.url) }
                            else if let url = item.url, let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("issueEditor.previewImage")
                            }
                        }.padding(16).navigationTitle("影像预览").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } }
                    }
                }
        }.onChange(of: workspace.identityRevision) { _, _ in draft.discard(); dismiss() }
            .onDisappear { if !picking && preview == nil { draft.discard() } }
    }
}
