import Foundation

/// Claims are journalled and idempotent. Login never overwrites a different account.
@MainActor
final class LocalIdentityScopes {
    let root: URL
    private let files = FileManager.default
    private struct GuestPointer: Codable { let id: String }
    private struct Owner: Codable { let account: String }
    private struct Journal: Codable { let guest: String }

    init(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
    }

    func accountDirectory(_ account: String) throws -> URL {
        guard valid(account, pattern: "\\A[a-f0-9]{64}\\z") else { throw CoreFailure(message: "账号校验失败，请重新登录") }
        return root.appending(path: "accounts/\(account)")
    }

    func guestDirectory() throws -> URL {
        let pointer = root.appendingPathComponent("guest-current.json")
        var id: String?
        if files.fileExists(atPath: pointer.path) {
            do { id = try JSONDecoder().decode(GuestPointer.self, from: Data(contentsOf: pointer)).id }
            catch { throw CoreFailure(message: "本机未登录记录目录读取失败，原文件已保留") }
            guard let id, validGuest(id) else { throw CoreFailure(message: "本机未登录记录目录无效，原文件已保留") }
        }
        if let current = id, try owner(in: guest(current)) != nil { id = nil }
        if id == nil {
            let fresh = "h" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            try files.createDirectory(at: guest(fresh), withIntermediateDirectories: true)
            try JSONEncoder().encode(GuestPointer(id: fresh)).write(to: pointer, options: .atomic)
            id = fresh
        }
        return guest(id!)
    }

    func claim(account: String, from source: NativeStore?, packs: Int = 0) throws -> NativeStore {
        let directory = try accountDirectory(account)
        let target = try NativeStore(directory: directory, packs: packs)
        guard !target.status.blocked else { throw CoreFailure(message: "账号记录读取失败，请先恢复记录") }
        let journal = directory.appendingPathComponent("guest-claim.json")
        if files.fileExists(atPath: journal.path) {
            let pending: Journal
            do { pending = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journal)) }
            catch { throw CoreFailure(message: "本机记录关联进度读取失败，原记录已保留") }
            guard validGuest(pending.guest) else { throw CoreFailure(message: "本机记录关联目录无效") }
            if !claimed(pending.guest, by: target) {
                let prior = try NativeStore(directory: guest(pending.guest))
                try transfer(prior, to: target, account: account, journal: journal)
            }
        }
        if let source { try transfer(source, to: target, account: account, journal: journal) }
        // A committed batch in state.json makes a leftover journal harmless.
        if files.fileExists(atPath: journal.path) { try? files.removeItem(at: journal) }
        return target
    }

    private func transfer(_ source: NativeStore, to target: NativeStore, account: String, journal: URL) throws {
        let sourceRoot = source.records.directory.standardizedFileURL.resolvingSymlinksInPath()
        let id = sourceRoot.lastPathComponent
        guard validGuest(id), sourceRoot.deletingLastPathComponent() == root.appendingPathComponent("guests") else {
            throw CoreFailure(message: "未登录记录目录无效，原记录已保留")
        }
        if claimed(id, by: target) { return }
        if let existing = try owner(in: sourceRoot), existing != account {
            throw CoreFailure(message: "这些本机记录已关联其他账号，请切回原账号")
        }
        guard !source.status.blocked else { throw CoreFailure(message: "本机记录读取失败，请先恢复记录后再登录") }
        try source.call("save")
        guard source.status.error.isEmpty else { throw CoreFailure(message: "本机内容尚未保存，请重试保存后再登录") }
        let defaults: JSONValue = .object(["template": .string("完整"), "hiddenFields": .array([]), "workplace": .string(""), "onboarding": .bool(true)])
        if source.houses.isEmpty && source.state["settings"] == defaults { return }
        let isNew = !files.fileExists(atPath: target.records.directory.appendingPathComponent("state.json").path)
        try JSONEncoder().encode(Journal(guest: id)).write(to: journal, options: .atomic)
        try JSONEncoder().encode(Owner(account: account)).write(to: sourceRoot.appendingPathComponent("account-owner.json"), options: .atomic)
        var created: [URL] = []
        do {
            let houses = try source.state["houses"].array.map { house in
                let media = try house["media"].array.map { item in
                    let original = try mediaURL(item["path"].string, in: sourceRoot)
                    let name = "\(UUID().uuidString).\(item["type"].string == "video" ? "mp4" : "jpg")"
                    let relative = "media/" + name
                    let destination = target.records.directory.appending(path: relative)
                    try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try files.copyItem(at: original, to: destination)
                    created.append(destination)
                    return item.setting("path", to: .string(relative))
                }
                return house.setting("media", to: .array(media))
            }
            let incoming = source.state.setting("houses", to: .array(houses))
            try target.call("claimGuest", ["id": .string(id), "value": incoming, "isNew": .bool(isNew)])
        } catch {
            for url in created { try? files.removeItem(at: url) }
            throw error
        }
    }

    func mediaURL(_ path: String, in directory: URL) throws -> URL {
        guard path.range(of: "\\Amedia/[A-Za-z0-9_-]+\\.(jpg|mp4)\\z", options: .regularExpression) != nil else {
            throw CoreFailure(message: "本机影像路径无效，原记录已保留")
        }
        let mediaRoot = directory.appendingPathComponent("media").standardizedFileURL.resolvingSymlinksInPath()
        let url = directory.appending(path: path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.deletingLastPathComponent() == mediaRoot else { throw CoreFailure(message: "本机影像路径无效，原记录已保留") }
        return url
    }
    private func claimed(_ id: String, by target: NativeStore) -> Bool {
        target.state["guestClaims"].array.contains(.string(id))
    }
    private func owner(in directory: URL) throws -> String? {
        let url = directory.appendingPathComponent("account-owner.json")
        guard files.fileExists(atPath: url.path) else { return nil }
        guard let owner = try? JSONDecoder().decode(Owner.self, from: Data(contentsOf: url)), valid(owner.account, pattern: "\\A[a-f0-9]{64}\\z") else {
            throw CoreFailure(message: "本机记录归属信息损坏，原文件已保留")
        }
        return owner.account
    }
    private func guest(_ id: String) -> URL { root.appending(path: "guests/\(id)") }
    private func validGuest(_ id: String) -> Bool { valid(id, pattern: "\\Ah[a-f0-9]{32}\\z") }
    private func valid(_ value: String, pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
}
