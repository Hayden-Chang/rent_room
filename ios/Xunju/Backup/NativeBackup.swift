import Foundation
import CryptoKit
import ZIPFoundation

struct BackupPreview: Sendable {
    let manifest: JSONValue
    let fingerprint: String
    var houses: [JSONValue] { manifest["houses"].array }
}
struct StagedBackup: Sendable {
    let houses: [JSONValue]
    let files: [URL]
}

/// Archive work stays off the main actor and streams media in bounded chunks.
actor NativeBackup {
    private let chunk = 256 * 1024
    private let maxManifest = 32 * 1024 * 1024

    func export(houses: [JSONValue], root: URL, to output: URL, progress: Progress? = nil) throws {
        guard !houses.isEmpty else { throw CoreFailure(message: "请选择要导出的房源") }
        guard !FileManager.default.fileExists(atPath: output.path) else { throw CoreFailure(message: "导出文件已存在") }
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: output) } }
        let archive = try Archive(url: output, accessMode: .create)
        var exported: [JSONValue] = [], houseIDs = Set<String>()
        for house in houses {
            guard safeID(house.id), houseIDs.insert(house.id).inserted else { throw CoreFailure(message: "房源编号无效或重复") }
            var mediaIDs = Set<String>(), media: [JSONValue] = []
            for item in house["media"].array {
                try check(progress)
                guard safeID(item.id), mediaIDs.insert(item.id).inserted, ["image", "video"].contains(item["type"].string) else {
                    throw CoreFailure(message: "影像编号无效或重复")
                }
                let source = try localMedia(item["path"].string, root: root)
                let handle = try FileHandle(forReadingFrom: source)
                defer { try? handle.close() }
                let size = try handle.seekToEnd()
                guard size <= 9007199254740991 else { throw CoreFailure(message: "影像文件过大") }
                let path = "media/\(house.id)/\(item.id).\(item["type"].string == "video" ? "mp4" : "jpg")"
                try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(size), bufferSize: chunk) { position, count in
                    try self.check(progress)
                    try handle.seek(toOffset: UInt64(position))
                    let data = try handle.read(upToCount: count) ?? Data()
                    guard data.count == count else { throw CoreFailure(message: "影像读取未完成") }
                    return data
                }
                guard let entry = archive[path] else { throw CoreFailure(message: "ZIP 生成未完成") }
                media.append(item.removing("thumb").setting("path", to: .string(path))
                    .setting("size", to: .number(Double(size))).setting("crc32", to: .number(Double(entry.checksum))))
            }
            exported.append(house.setting("media", to: .array(media)))
        }
        let manifest: JSONValue = .object(["version": .number(2), "format": .string("xunju-backup"), "archiveVersion": .number(1),
            "exportedAt": .string(ISO8601DateFormatter().string(from: Date())), "houses": .array(exported)])
        let data = try JSONEncoder().encode(manifest)
        guard data.count <= maxManifest else { throw CoreFailure(message: "房源清单数据过大") }
        try check(progress)
        try archive.addEntry(with: "manifest.json", type: .file, uncompressedSize: Int64(data.count), bufferSize: chunk) { position, count in
            data.subdata(in: Int(position)..<(Int(position) + count))
        }
        complete = true
    }

    func preview(_ url: URL, progress: Progress? = nil) throws -> BackupPreview {
        try check(progress)
        let index = try ZIPIndex(url: url)
        let archive = try Archive(url: url, accessMode: .read)
        let entries = Array(archive)
        guard Set(entries.map(\.path)) == index.names, entries.allSatisfy({ $0.type == .file }),
              entries.allSatisfy({ $0.path == "manifest.json" || validMediaPath($0.path) }),
              let entry = archive["manifest.json"], entry.uncompressedSize <= UInt64(maxManifest) else {
            throw CoreFailure(message: "不是本应用导出的房源 ZIP")
        }
        var data = Data()
        let checksum = try archive.extract(entry, bufferSize: chunk) { part in
            try self.check(progress)
            guard part.count <= self.maxManifest - data.count else { throw CoreFailure(message: "房源清单数据过大") }
            data.append(part)
        }
        guard checksum == entry.checksum, UInt64(data.count) == entry.uncompressedSize else { throw CoreFailure(message: "ZIP 房源清单损坏") }
        let raw: JSONValue
        do { raw = try JSONDecoder().decode(JSONValue.self, from: data) }
        catch { throw CoreFailure(message: "ZIP 房源清单损坏，请重新导出") }
        guard raw["format"].string == "xunju-backup", raw["archiveVersion"] == .number(1), !raw["houses"].array.isEmpty else {
            throw CoreFailure(message: "不是本应用导出的房源 ZIP")
        }
        var referenced = Set(["manifest.json"])
        for house in raw["houses"].array {
            for media in house["media"].array {
                let path = media["path"].string
                guard validMediaPath(path), referenced.insert(path).inserted, let entry = archive[path], entry.uncompressedSize <= 9007199254740991,
                      media["size"] == .number(Double(entry.uncompressedSize)), media["crc32"] == .number(Double(entry.checksum)) else {
                    throw CoreFailure(message: "备份影像缺失或数据无效")
                }
            }
        }
        guard referenced == index.names else { throw CoreFailure(message: "ZIP 内容与房源清单不一致") }
        return BackupPreview(manifest: raw, fingerprint: try fingerprint(url, progress: progress))
    }

    func stage(_ url: URL, preview expected: BackupPreview, selectedIDs: Set<String>, into root: URL, progress: Progress? = nil) throws -> StagedBackup {
        let current = try preview(url, progress: progress)
        guard current.fingerprint == expected.fingerprint else { throw CoreFailure(message: "备份文件已变化，请重新选择") }
        guard !selectedIDs.isEmpty, selectedIDs.isSubset(of: Set(current.houses.map(\.id))) else {
            throw CoreFailure(message: "请选择要导入的房源")
        }
        let archive = try Archive(url: url, accessMode: .read)
        var created: [URL] = [], complete = false
        defer { if !complete { for url in created { try? FileManager.default.removeItem(at: url) } } }
        var houses: [JSONValue] = []
        for house in current.houses where selectedIDs.contains(house.id) {
            var media: [JSONValue] = []
            for item in house["media"].array {
                try check(progress)
                guard let entry = archive[item["path"].string] else { throw CoreFailure(message: "备份影像缺失") }
                let relative = "media/\(UUID().uuidString).\(item["type"].string == "video" ? "mp4" : "jpg")"
                let destination = root.appending(path: relative)
                _ = try LocalMediaFiles.directory(in: root, create: true)
                guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw CoreFailure(message: "影像保存失败") }
                created.append(destination)
                let handle = try FileHandle(forWritingTo: destination)
                defer { try? handle.close() }
                var size: UInt64 = 0
                let expectedSize = entry.uncompressedSize, expectedChecksum = entry.checksum
                let checksum = try archive.extract(entry, bufferSize: chunk) { data in
                    try self.check(progress)
                    guard UInt64(data.count) <= expectedSize - size else { throw CoreFailure(message: "备份影像大小不一致") }
                    size += UInt64(data.count)
                    try handle.write(contentsOf: data)
                }
                guard size == expectedSize, checksum == expectedChecksum else { throw CoreFailure(message: "备份影像损坏，请重新导出") }
                media.append(item.removing("thumb").setting("path", to: .string(relative)))
            }
            houses.append(house.setting("media", to: .array(media)))
        }
        try check(progress)
        complete = true
        return StagedBackup(houses: houses, files: created)
    }

    func discard(_ stage: StagedBackup) { for url in stage.files { try? FileManager.default.removeItem(at: url) } }

    private func fingerprint(_ url: URL, progress: Progress?) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let part = try handle.read(upToCount: chunk), !part.isEmpty { try check(progress); hash.update(data: part) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private func check(_ progress: Progress?) throws {
        if progress?.isCancelled == true { throw CoreFailure(message: "已取消操作") }
    }
    private func safeID(_ id: String) -> Bool { id.range(of: "\\A[a-zA-Z0-9_-]+\\z", options: .regularExpression) != nil }
    private func validMediaPath(_ path: String) -> Bool {
        path.range(of: "\\Amedia/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\\.(jpg|mp4)\\z", options: .regularExpression) != nil
    }
    private func localMedia(_ path: String, root: URL) throws -> URL {
        try LocalMediaFiles.file(path, in: root)
    }
}
