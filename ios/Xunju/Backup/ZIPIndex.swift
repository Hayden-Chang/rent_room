import Foundation

/// Inspect every central/local header before ZIPFoundation inflates selected files.
/// This also rejects unsupported skipped entries and incomplete/trailing ZIP data.
struct ZIPIndex {
    let names: Set<String>

    init(url: URL) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        func read(_ offset: UInt64, _ length: Int) throws -> Data {
            guard length >= 0, offset <= size, UInt64(length) <= size - offset else { throw Self.invalid }
            try file.seek(toOffset: offset)
            let data = try file.read(upToCount: length) ?? Data()
            guard data.count == length else { throw Self.invalid }
            return data
        }
        let tail = try read(size - min(size, 65557), Int(min(size, 65557)))
        guard tail.count >= 22 else { throw Self.invalid }
        var end: Int?
        for at in stride(from: tail.count - 22, through: 0, by: -1) {
            if try tail.uint(at, 4) == 0x06054b50, at + 22 + Int(try tail.uint(at + 20, 2)) == tail.count { end = at; break }
        }
        guard let end else { throw Self.invalid }
        let endOffset = size - UInt64(tail.count) + UInt64(end)
        guard try tail.uint(end + 4, 2) == 0, try tail.uint(end + 6, 2) == 0 else { throw Self.invalid }
        var count = try tail.uint(end + 10, 2)
        var directorySize = try tail.uint(end + 12, 4)
        var offset = try tail.uint(end + 16, 4)
        if count == 0xffff || directorySize == 0xffffffff || offset == 0xffffffff {
            guard endOffset >= 20 else { throw Self.invalid }
            let locator = try read(endOffset - 20, 20)
            guard try locator.uint(0, 4) == 0x07064b50, try locator.uint(4, 4) == 0, try locator.uint(16, 4) == 1 else { throw Self.invalid }
            let record = try read(locator.uint(8, 8), 56)
            guard try record.uint(0, 4) == 0x06064b50, try record.uint(16, 4) == 0, try record.uint(20, 4) == 0,
                  try record.uint(24, 8) == (try record.uint(32, 8)) else { throw Self.invalid }
            count = try record.uint(32, 8); directorySize = try record.uint(40, 8); offset = try record.uint(48, 8)
        } else if try tail.uint(end + 8, 2) != count { throw Self.invalid }
        guard offset <= endOffset, directorySize <= endOffset - offset, count <= directorySize / 46 else { throw Self.invalid }
        let limit = offset + directorySize
        var names = Set<String>()
        for _ in 0..<count {
            let header = try read(offset, 46)
            guard try header.uint(0, 4) == 0x02014b50, try header.uint(8, 2) & 1 == 0,
                  try [0, 8].contains(header.uint(10, 2)) else { throw Self.invalid }
            let nameLength = Int(try header.uint(28, 2)), extraLength = Int(try header.uint(30, 2))
            let commentLength = Int(try header.uint(32, 2))
            let name = try read(offset + 46, nameLength)
            guard let path = String(data: name, encoding: .utf8), names.insert(path).inserted else { throw Self.invalid }
            var localOffset = try header.uint(42, 4)
            if localOffset == 0xffffffff {
                let extra = try read(offset + 46 + UInt64(nameLength), extraLength)
                var at = 0, found = false
                while at + 4 <= extra.count {
                    let length = Int(try extra.uint(at + 2, 2))
                    guard length <= extra.count - at - 4 else { throw Self.invalid }
                    if try extra.uint(at, 2) == 1 {
                        var valueAt = at + 4
                        if try header.uint(24, 4) == 0xffffffff { valueAt += 8 }
                        if try header.uint(20, 4) == 0xffffffff { valueAt += 8 }
                        guard valueAt + 8 <= at + 4 + length else { throw Self.invalid }
                        localOffset = try extra.uint(valueAt, 8); found = true; break
                    }
                    at += 4 + length
                }
                guard found else { throw Self.invalid }
            }
            let local = try read(localOffset, 30)
            guard try local.uint(0, 4) == 0x04034b50, try local.uint(6, 2) & 1 == 0,
                  try local.uint(8, 2) == (try header.uint(10, 2)), try local.uint(26, 2) == UInt64(nameLength),
                  try read(localOffset + 30, nameLength) == name else { throw Self.invalid }
            let step = UInt64(46 + nameLength + extraLength + commentLength)
            guard step <= limit - offset else { throw Self.invalid }
            offset += step
        }
        guard offset == limit else { throw Self.invalid }
        self.names = names
    }
    private static var invalid: CoreFailure { CoreFailure(message: "ZIP 文件不完整或包含不支持的条目") }
}

private extension Data {
    func uint(_ offset: Int, _ count: Int) throws -> UInt64 {
        guard offset >= 0, count > 0, count <= 8, offset <= self.count, count <= self.count - offset else {
            throw CoreFailure(message: "ZIP 元数据损坏")
        }
        return (0..<count).reduce(0) { $0 | UInt64(self[offset + $1]) << ($1 * 8) }
    }
}
