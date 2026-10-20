import Foundation
import Observation

/// A draft owns only newly imported files. Saved/recovery references always win
/// over cleanup, including after a failed transaction or an account change.
@MainActor @Observable final class IssueDraft {
    let store: NativeStore
    let houseID: String
    let issueID: String
    let isNew: Bool
    var title: String
    var note: String
    private(set) var media: [JSONValue]
    var titleError = ""
    var error = ""
    private(set) var saving = false
    private(set) var closed = false
    @ObservationIgnored private let isCurrent: () -> Bool
    @ObservationIgnored private let original: JSONValue
    @ObservationIgnored private var ownedPaths: Set<String> = []

    init(store: NativeStore, houseID: String, issueID: String, isNew: Bool, isCurrent: @escaping () -> Bool) {
        self.store = store; self.houseID = houseID; self.issueID = issueID; self.isNew = isNew; self.isCurrent = isCurrent
        let house = store.house(houseID), issue = house["issues"].array.first { $0.id == issueID } ?? .null
        let initialTitle = issue["title"].string, initialNote = issue["note"].string
        let initialMedia = house["media"].array.filter { $0["issueId"].string == issueID }
        title = initialTitle; note = initialNote; media = initialMedia
        original = .object(["title": .string(initialTitle), "note": .string(initialNote), "media": .array(initialMedia)])
    }
    var readonly: Bool { store.house(houseID)["archived"].bool }
    var dirty: Bool { !closed && draft != original }
    private var draft: JSONValue { .object(["title": .string(title), "note": .string(note), "media": .array(media)]) }

    func addImported(_ item: JSONValue) throws {
        try checkEditable()
        guard ["image", "video"].contains(item["type"].string), !item.id.isEmpty,
              !media.contains(where: { $0.id == item.id || $0["path"] == item["path"] }) else {
            throw CoreFailure(message: "影像数据无效或已添加")
        }
        let path = item["path"].string
        try requireFile(path)
        guard !(try LocalMediaReferences.isReferenced(path, in: store)) else {
            throw CoreFailure(message: "影像已被记录引用，请重新选择")
        }
        ownedPaths.insert(path); media.append(item); error = ""
    }
    func remove(_ item: JSONValue) {
        do {
            try checkEditable()
            media.removeAll { $0.id == item.id }; error = ""
            if ownedPaths.contains(item["path"].string) { LocalMediaReferences.discard([item["path"].string], in: store) }
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult func save() -> Bool {
        guard !saving else { return false }
        titleError = ""; error = ""
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            titleError = "请填写问题标题"; return false
        }
        saving = true; defer { saving = false }
        do {
            try checkEditable()
            for item in media { try requireFile(item["path"].string) }
            try store.call("writeIssue", ["id": .string(houseID), "issueId": .string(issueID), "isNew": .bool(isNew), "draft": draft])
            closed = true
            LocalMediaReferences.discard(ownedPaths, in: store)
            ownedPaths.removeAll()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func discard() {
        guard !closed else { return }; closed = true
        LocalMediaReferences.discard(ownedPaths, in: store); ownedPaths.removeAll()
    }
    private func checkEditable() throws {
        guard !closed, isCurrent() else { throw CoreFailure(message: "账号或编辑页面已变化，请重新打开问题") }
        guard !store.house(houseID).id.isEmpty else { throw CoreFailure(message: "房源已不存在") }
        guard !readonly else { throw CoreFailure(message: "归档房源只读，请先还原") }
    }
    private func requireFile(_ path: String) throws {
        let url = try LocalMediaFiles.file(path, in: store.records.directory)
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true, let size = values?.fileSize, size > 0, size <= 50 * 1024 * 1024 else {
            throw CoreFailure(message: "影像文件不存在或超过 50 MiB，请重新选择")
        }
    }
}

@MainActor enum LocalMediaReferences {
    static func isReferenced(_ path: String, in store: NativeStore) throws -> Bool {
        let referenced = try paths(in: store)
        let url = try LocalMediaFiles.file(path, in: store.records.directory)
        return referenced.contains(path) || targets(referenced, in: store).contains(url.path)
    }
    private static func targets(_ paths: Set<String>, in store: NativeStore) -> Set<String> {
        Set(paths.compactMap { try? LocalMediaFiles.file($0, in: store.records.directory).path })
    }
    static func paths(in store: NativeStore) throws -> Set<String> {
        var states = [store.state]
        for previous in [false, true] {
            let text = try store.records.read(previous: previous)
            if !text.isEmpty { states.append(try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))) }
        }
        var paths: Set<String> = []
        for state in states {
            guard [1, 2].contains(state["version"].int), case .array(let houses) = state["houses"] else {
                throw CoreFailure(message: "本机记录无法核对，影像文件已保留")
            }
            for house in houses { paths.formUnion(house["media"].array.map { $0["path"].string }) }
        }
        return paths
    }
    static func discard(_ candidates: Set<String>, in store: NativeStore) {
        guard let referenced = try? paths(in: store) else { return }
        let referencedTargets = targets(referenced, in: store)
        for path in candidates.subtracting(referenced) {
            guard let url = try? LocalMediaFiles.file(path, in: store.records.directory),
                  !referencedTargets.contains(url.path) else { continue }
            // Validate the resolved target, but unlink only the owned filename.
            // A symbolic alias must never turn cleanup into deleting its target.
            let ownedFile = url.deletingLastPathComponent().appendingPathComponent((path as NSString).lastPathComponent)
            try? FileManager.default.removeItem(at: ownedFile)
        }
    }
}
