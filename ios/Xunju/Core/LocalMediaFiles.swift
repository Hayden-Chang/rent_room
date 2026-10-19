import Foundation

/// Relative paths cannot alias a different account through files or directories.
enum LocalMediaFiles {
    static func directory(in root: URL, create: Bool = false) throws -> URL {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let directory = canonicalRoot.appendingPathComponent("media")
        if create { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        guard directory.resolvingSymlinksInPath().path == directory.path else {
            throw CoreFailure(message: "本机影像目录无效，原记录已保留")
        }
        return directory
    }

    static func file(_ path: String, in root: URL) throws -> URL {
        guard path.range(of: "\\Amedia/[A-Za-z0-9_-]+\\.(jpg|mp4)\\z", options: .regularExpression) != nil else {
            throw CoreFailure(message: "本机影像路径无效，原记录已保留")
        }
        let directory = try directory(in: root)
        let url = directory.appendingPathComponent((path as NSString).lastPathComponent).resolvingSymlinksInPath()
        guard url.deletingLastPathComponent().path == directory.path else {
            throw CoreFailure(message: "本机影像路径无效，原记录已保留")
        }
        return url
    }
}
