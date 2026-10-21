import SwiftUI

private struct IssueSelection: Identifiable { let id: String; let isNew: Bool }
struct IssuesPage: View {
    let workspace: AppWorkspace
    let id: String
    @State private var automatic: [JSONValue] = []
    @State private var coordinator = MPSwipeCoordinator()
    @State private var selection: IssueSelection?
    @State private var preview: MediaTile?
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
                    AutomaticIssueCard(category: field["category"].string) {
                        InspectionFieldRow(workspace: workspace, houseID: id, field: field, coordinator: coordinator)
                    }
                }
                ForEach(manual, id: \.id) { issue in
                    ManualIssueCard(id: issue.id, title: issue["title"].string, note: issue["note"].string,
                        media: workspace.store.house(id)["media"].array.filter { $0["issueId"].string == issue.id }.map { mediaTile($0, store: workspace.store) },
                        resolved: issue["resolved"].bool, readonly: readonly,
                        resolve: { workspace.perform { try workspace.store.call("resolveIssue", ["id": .string(id), "issueId": .string(issue.id)]) } },
                        open: { selection = IssueSelection(id: issue.id, isNew: false) }, preview: { preview = $0 })
                }
            }.padding(16)
        }.safeAreaInset(edge: .bottom) {
            if !readonly { Button("新建问题") { selection = IssueSelection(id: "i" + UUID().uuidString.replacingOccurrences(of: "-", with: ""), isNew: true) }
                .buttonStyle(XJButtonStyle(primary: true)).padding(16).accessibilityIdentifier("issue.add") }
        }.onAppear(perform: refresh).onChange(of: workspace.store.status.revision) { _, _ in refresh() }
            .sheet(item: $selection) { selection in IssueEditor(workspace: workspace, houseID: id, issueID: selection.id, isNew: selection.isNew) }
            .sheet(item: $preview) { MediaPreviewSheet(item: $0) }
            .toolbar { ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityIdentifier("issues.keyboard.done")
            } }
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
                .fullScreenCover(isPresented: $picking) {
                    MediaPickerSheet(workspace: workspace, houseID: draft.houseID, stage: { try draft.addImported($0) })
                }
                .sheet(item: $preview) { item in
                    MediaPreviewSheet(item: item, imageIdentifier: "issueEditor.previewImage")
                }
        }.onChange(of: workspace.identityRevision) { _, _ in draft.discard(); dismiss() }
            .onDisappear { if !picking && preview == nil { draft.discard() } }
    }
}
