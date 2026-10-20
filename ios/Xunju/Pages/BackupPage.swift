import SwiftUI
import UniformTypeIdentifiers

struct BackupPage: View {
    let workspace: AppWorkspace
    var importing = false
    var initialIDs: Set<String> = []
    @State private var selected = Set<String>()
    @State private var replace = Set<String>()
    @State private var preview: BackupPreview?
    @State private var input: URL?
    @State private var output: URL?
    @State private var choosing = false
    @State private var confirming = false
    @State private var busy = false
    @State private var error = ""
    @State private var message = ""
    @State private var task: Task<Void, Never>?
    @State private var progress = Progress(totalUnitCount: 1)
    private let transfers = BackupTransfers()
    private var houses: [JSONValue] { importing ? preview?.houses ?? [] : workspace.store.state["houses"].array }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("仅支持寻居导出的房源 ZIP，包含记录与影像。").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                if importing { Button(input?.lastPathComponent ?? "选择 ZIP 文件") { choosing = true }.buttonStyle(XJButtonStyle(primary: false)).disabled(busy) }
                if !houses.isEmpty {
                    Button(selected.count == houses.count ? "取消全选" : "全选") { selected = selected.count == houses.count ? [] : Set(houses.map(\.id)); output = nil }.disabled(busy)
                }
                ForEach(houses, id: \.id) { house in
                    XJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(house["name"].string, isOn: Binding(get: { selected.contains(house.id) }, set: { on in
                                if on { selected.insert(house.id) } else { selected.remove(house.id) }; output = nil
                            })).font(.system(size: 14)).tint(XJTheme.primary).disabled(busy)
                                .accessibilityIdentifier("backup.select.\(house["name"].string)")
                            Text("\(house["media"].array.count) 个影像" + (house["archived"].bool ? " · 已归档" : "")).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                            if importing && workspace.store.house(house.id) != .null {
                                Picker("同编号房源", selection: Binding(get: { replace.contains(house.id) }, set: { value in
                                    if value { replace.insert(house.id) } else { replace.remove(house.id) }
                                })) { Text("新增副本").tag(false); Text("覆盖原房源").tag(true) }.pickerStyle(.segmented).disabled(busy)
                            }
                        }
                    }
                }
                if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger).accessibilityIdentifier("backup.error") }
                if !message.isEmpty { Text(message).font(.system(size: 14)).accessibilityIdentifier("backup.result") }
                if busy { ProgressView(importing ? "正在读取并校验 ZIP…" : "正在生成 ZIP…"); Button("取消") { progress.cancel(); task?.cancel() } }
                else if let output {
                    ShareLink(item: output) { Text("分享房源 ZIP").frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("backup.share")
                } else {
                    Button(importing ? "导入选中房源" : "生成房源 ZIP") {
                        if importing && !replace.intersection(selected).isEmpty { confirming = true }
                        else { start() }
                    }.buttonStyle(XJButtonStyle(primary: true)).disabled(selected.isEmpty)
                        .accessibilityIdentifier("backup.commit")
                }
            }.padding(16)
        }.background(XJTheme.background).navigationTitle(importing ? "导入房源" : "导出房源").navigationBarTitleDisplayMode(.inline)
            .onAppear { if !importing && selected.isEmpty { selected = initialIDs.isEmpty ? Set(houses.map(\.id)) : initialIDs } }
            .onDisappear { progress.cancel(); task?.cancel() }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.zip]) { result in
                switch result {
                case .success(let url): read(url)
                case .failure(let failure): error = failure.localizedDescription
                }
            }
            .confirmationDialog("覆盖 \(replace.intersection(selected).count) 套房源？", isPresented: $confirming, titleVisibility: .visible) {
                Button("整套替换记录和影像", role: .destructive) { start() }
            } message: { Text("被覆盖的房源记录和附件将被整套替换。") }
    }
    private func read(_ url: URL) {
        guard !busy else { return }
        busy = true; error = ""; message = ""; preview = nil; selected = []; replace = []
        progress = Progress(totalUnitCount: 1)
        let store = workspace.store
        task = Task { @MainActor in
            defer { busy = false }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let directory = FileManager.default.temporaryDirectory.appending(path: "XunjuTransfers/\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let local = directory.appending(path: "房源备份.zip")
                try await Task.detached { try FileManager.default.copyItem(at: url, to: local) }.value
                let result = try await transfers.preview(local, store: store, progress: progress)
                try Task.checkCancellation()
                guard workspace.store === store else { throw CoreFailure(message: "账号已变化，请重新选择") }
                input = local; preview = result; selected = Set(result.houses.map(\.id))
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    private func start() {
        guard !busy else { return }
        busy = true; error = ""; message = ""; progress = Progress(totalUnitCount: 1)
        let store = workspace.store, ids = selected, replacements = replace.intersection(selected)
        task = Task { @MainActor in
            defer { busy = false }
            do {
                if importing {
                    guard let input, let preview else { throw CoreFailure(message: "请先选择房源 ZIP") }
                    let copies = Set(preview.houses.filter { ids.contains($0.id) && store.house($0.id) != .null && !replacements.contains($0.id) }.map(\.id))
                    try await transfers.importSelected(input, preview: preview, selectedIDs: ids, replacing: Array(replacements), copying: copies,
                        store: store, progress: progress, isCurrent: { workspace.store === store })
                    message = "已导入 \(ids.count) 套房源"; selected = []
                } else {
                    let directory = FileManager.default.temporaryDirectory.appending(path: "XunjuTransfers/\(UUID().uuidString)")
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let url = directory.appending(path: "寻居房源备份.zip")
                    try await transfers.export(ids: Array(ids).sorted(), store: store, to: url, progress: progress)
                    try Task.checkCancellation()
                    output = url; message = "ZIP 已生成，包含 \(ids.count) 套房源及其影像"
                }
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
