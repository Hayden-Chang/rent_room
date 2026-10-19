import Foundation

@MainActor
final class BackupTransfers {
    private let worker = NativeBackup()

    func preview(_ url: URL, store: NativeStore, progress: Progress? = nil) async throws -> BackupPreview {
        let preview = try await worker.preview(url, progress: progress)
        // Apply exactly the mini-program's schema and migration validation.
        try store.call("prepareImport", ["value": preview.manifest])
        return preview
    }
    func export(ids: [String], store: NativeStore, to url: URL, progress: Progress? = nil) async throws {
        guard !ids.isEmpty, Set(ids).count == ids.count, ids.allSatisfy({ store.house($0) != .null }) else {
            throw CoreFailure(message: "请选择要导出的房源")
        }
        guard !store.status.blocked else { throw CoreFailure(message: "本机记录读取失败，请先恢复记录") }
        let houses = ids.map { store.house($0) }
        try await worker.export(houses: houses, root: store.records.directory, to: url, progress: progress)
    }
    func importSelected(_ url: URL, preview: BackupPreview, selectedIDs: Set<String>, replacing: [String],
                        store: NativeStore, progress: Progress? = nil, isCurrent: @MainActor () -> Bool) async throws {
        guard isCurrent() else { throw CoreFailure(message: "账号已变化，请重新选择") }
        let revision = store.status.revision
        let staged = try await worker.stage(url, preview: preview, selectedIDs: selectedIDs, into: store.records.directory, progress: progress)
        do {
            guard isCurrent(), revision == store.status.revision, progress?.isCancelled != true else {
                throw CoreFailure(message: "账号或房源记录已变化，请重新选择导入")
            }
            let prepared = try store.call("prepareImport", ["value": .object(["version": .number(2), "houses": .array(staged.houses)])])
            try store.call("import", ["houses": prepared, "replaceIds": .array(replacing.map(JSONValue.string))])
        } catch {
            await worker.discard(staged)
            throw error
        }
    }
}
