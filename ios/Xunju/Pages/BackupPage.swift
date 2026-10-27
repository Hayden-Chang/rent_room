import SwiftUI
import UniformTypeIdentifiers

struct BackupPage: View {
    let workspace: AppWorkspace
    var importing = false
    var initialIDs: Set<String> = []
    @State private var selected = Set<String>()
    @State private var replace = Set<String>()
    @State private var conflictModes: [String: MPConflictMode] = [:]
    @Environment(\.dismiss) private var dismiss
    @State private var preview: BackupPreview?
    @State private var input: URL?
    @State private var fileName = ""
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(importing ? "选择要导入的房源" : "选择要导出的房源").font(.system(size: 22, weight: .semibold)).frame(minHeight: 30.8)
                    if importing {
                        VStack(spacing: 0) {
                            Text(fileName.isEmpty ? "尚未选择 ZIP 文件" : fileName).font(.system(size: 12)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                            Button(input == nil ? "选择 ZIP 文件" : "重新选择 ZIP") { choosing = true }
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.primary).frame(minHeight: 44).disabled(busy)
                        }.padding(.horizontal, 16).padding(.vertical, 12).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !error.isEmpty { Text(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("backup.error") }
                    if !houses.isEmpty {
                        HStack {
                            Text("共 \(houses.count) 套，已选 \(selected.count) 套").font(.system(size: 14))
                            Spacer()
                            Button(selected.count == houses.count ? "取消全选" : "全选") { selected = selected.count == houses.count ? [] : Set(houses.map(\.id)); output = nil }
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.primary).frame(minHeight: 44)
                        }.padding(.bottom, 12)
                    }
                    ForEach(houses, id: \.id) { house in
                        MPCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    if !selected.insert(house.id).inserted { selected.remove(house.id) }; output = nil
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        MPCheckbox(selected: selected.contains(house.id)).padding(.top, 4)
                                        VStack(alignment: .leading, spacing: 0) {
                                            HStack(spacing: 8) {
                                                Text(house["name"].string).font(.system(size: 17, weight: .semibold)).frame(minHeight: 25.5)
                                                if house["archived"].bool { Text("已归档").font(.system(size: 11)).padding(.horizontal, 8).padding(.vertical, 3).foregroundStyle(XJTheme.primary).background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6)) }
                                            }
                                            Text(house["address"].string.isEmpty ? "地址未填写" : house["address"].string).font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted).frame(minHeight: 18)
                                            Text("\(answerCount(house)) 条检查记录 · \(house["media"].array.count) 个影像").font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted).frame(minHeight: 18)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("backup.select.\(house["name"].string)")
                                    .accessibilityAddTraits(selected.contains(house.id) ? .isSelected : [])
                                if importing && selected.contains(house.id), workspace.store.house(house.id) != .null {
                                    XJTheme.line.frame(height: 1)
                                    Text("本机已有「\(workspace.store.house(house.id)["name"].string)」，请选择处理方式").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.vertical, 6)
                                    HStack(spacing: 8) {
                                        conflictButton("覆盖", mode: .replace, house: house.id)
                                        conflictButton("新增副本", mode: .copy, house: house.id)
                                    }
                                }
                            }
                        }.padding(.bottom, 12)
                    }
                    if houses.isEmpty && !importing { Text("还没有可导出的房源").font(.system(size: 14)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity).padding(.top, 56) }
                }.padding(16).disabled(busy)
            }
            VStack(spacing: 12) {
                if busy { ProgressView(importing ? "正在读取并校验 ZIP…" : "正在生成 ZIP…") }
                if !message.isEmpty { Text(message).font(.system(size: 12)).foregroundStyle(XJTheme.muted).accessibilityIdentifier("backup.result") }
                HStack(spacing: 8) {
                    Button(busy ? "取消操作" : "取消") {
                        if busy { progress.cancel(); task?.cancel() } else { dismiss() }
                    }.buttonStyle(MPButtonStyle())
                    if let output {
                        ShareLink(item: output) { Text("导出 \(selected.count) 套") }
                            .buttonStyle(MPButtonStyle(kind: .primary)).accessibilityIdentifier("backup.share")
                    } else {
                        Button(importing ? "导入 \(selected.count) 套" : "导出 \(selected.count) 套") {
                            if importing && !replace.intersection(selected).isEmpty { confirming = true }
                            else { start() }
                        }.buttonStyle(MPButtonStyle(kind: .primary, transferDisabled: true)).disabled(busy || !selectionReady)
                            .accessibilityIdentifier("backup.commit")
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16).background(.white).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
        }.foregroundStyle(XJTheme.ink).background(XJTheme.background).miniNavigation(importing ? "导入房源" : "导出房源")
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
    private var selectionReady: Bool {
        MPTransferSelection.ready(items: houses.map { house in
            MPTransferItem(id: house.id, name: house["name"].string, address: house["address"].string,
                           fields: answerCount(house), media: house["media"].array.count,
                           archived: house["archived"].bool,
                           conflictName: workspace.store.house(house.id) == .null ? nil : workspace.store.house(house.id)["name"].string)
        }, selected: selected, modes: conflictModes, exporting: !importing)
    }
    private func answerCount(_ house: JSONValue) -> Int {
        if case .object(let answers) = house["answers"] { return answers.count }; return 0
    }
    private func conflictButton(_ title: String, mode: MPConflictMode, house: String) -> some View {
        Button(title) {
            conflictModes[house] = mode
            if mode == .replace { replace.insert(house) } else { replace.remove(house) }
        }.buttonStyle(MPButtonStyle(kind: conflictModes[house] == mode ? .soft : .plain))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(conflictModes[house] == mode ? XJTheme.primary : XJTheme.line))
            .accessibilityAddTraits(conflictModes[house] == mode ? .isSelected : [])
    }
    private func read(_ url: URL) {
        guard !busy else { return }
        busy = true; error = ""; message = ""; preview = nil; input = nil; fileName = ""; selected = []; replace = []; conflictModes = [:]
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
                input = local; fileName = url.lastPathComponent; preview = result; selected = Set(result.houses.map(\.id))
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
