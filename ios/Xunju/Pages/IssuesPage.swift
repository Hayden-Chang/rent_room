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
    let houseID: String
    let issueID: String
    let isNew: Bool
    @State private var title = ""
    @State private var note = ""
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    private var readonly: Bool { workspace.store.house(houseID)["archived"].bool }
    var body: some View {
        NavigationStack {
            Form {
                TextField("问题标题", text: $title).accessibilityIdentifier("issue.title").disabled(readonly)
                    .onChange(of: title) { _, value in if value.count > 200 { title = String(value.prefix(200)) } }
                TextEditor(text: $note).frame(minHeight: 160).accessibilityIdentifier("issue.note").disabled(readonly)
                    .onChange(of: note) { _, value in if value.count > 10000 { note = String(value.prefix(10000)) } }
                if !error.isEmpty { Text(error).foregroundStyle(XJTheme.danger) }
            }.navigationTitle(isNew ? "新建问题" : "问题详情").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(readonly ? "关闭" : "取消") { dismiss() } }
                    if !readonly { ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
                }.onAppear {
                    if let item = workspace.store.house(houseID)["issues"].array.first(where: { $0.id == issueID }) { title = item["title"].string; note = item["note"].string }
                }
        }
    }
    private func save() {
        do {
            let media = workspace.store.house(houseID)["media"].array.filter { $0["issueId"].string == issueID }
            try workspace.store.call("writeIssue", ["id": .string(houseID), "issueId": .string(issueID), "isNew": .bool(isNew),
                "draft": .object(["title": .string(title), "note": .string(note), "media": .array(media)])])
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
