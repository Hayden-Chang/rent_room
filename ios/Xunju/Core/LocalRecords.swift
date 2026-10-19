import Foundation

/// Files remain scoped to one local identity. The prior complete save is preserved.
final class LocalRecords {
    let directory: URL
    private var current: URL { directory.appendingPathComponent("state.json") }
    private var previous: URL { directory.appendingPathComponent("state.previous.json") }

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var protected = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        try protected.setResourceValues(values)
    }

    func read(previous: Bool = false) throws -> String {
        let url = previous ? self.previous : current
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func write(_ text: String, keepPrevious: Bool) throws {
        let data = Data(text.utf8)
        if !keepPrevious && FileManager.default.fileExists(atPath: current.path) {
            try Data(contentsOf: current).write(to: previous, options: .atomic)
        }
        try data.write(to: current, options: .atomic)
    }

    func preserveCorrupt() throws {
        guard FileManager.default.fileExists(atPath: current.path) else { return }
        let copy = directory.appendingPathComponent("state.corrupt.\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: current, to: copy)
    }
}
