import Foundation

/// Account-local profile; intentionally separate from house state and ZIP exports.
struct LocalAccountProfile {
    struct Value: Codable, Equatable {
        var nickname = ""
        var avatarFile = ""
    }
    let directory: URL
    private var file: URL { directory.appending(path: "profile.json") }
    func read() -> Value {
        guard let data = try? Data(contentsOf: file), var value = try? JSONDecoder().decode(Value.self, from: data) else { return Value() }
        value.nickname = String(value.nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
        if avatarURL(value) == nil { value.avatarFile = "" }
        return value
    }
    func avatarURL(_ value: Value) -> URL? {
        guard value.avatarFile.range(of: "^profile-avatar-[A-Za-z0-9-]+\\.png$", options: .regularExpression) != nil else { return nil }
        let url = directory.appending(path: value.avatarFile)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    @discardableResult func saveNickname(_ text: String) throws -> Value {
        let nickname = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty, nickname.count <= 32 else { throw CoreFailure(message: "昵称请填写 1～32 个字") }
        var value = read(); value.nickname = nickname
        try write(value); return value
    }
    @discardableResult func saveAvatar(_ png: Data) throws -> Value {
        guard png.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]), png.count <= 5 * 1024 * 1024 else { throw CoreFailure(message: "头像读取失败，请重新选择") }
        let previous = read()
        var value = previous; value.avatarFile = "profile-avatar-" + UUID().uuidString + ".png"
        let target = directory.appending(path: value.avatarFile)
        do { try png.write(to: target, options: .atomic); try write(value) }
        catch { try? FileManager.default.removeItem(at: target); throw error }
        if let old = avatarURL(previous) { try? FileManager.default.removeItem(at: old) }
        return value
    }
    private func write(_ value: Value) throws { try JSONEncoder().encode(value).write(to: file, options: .atomic) }
}
