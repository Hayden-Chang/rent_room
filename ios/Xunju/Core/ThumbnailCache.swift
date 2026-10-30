import UIKit
import ImageIO

/// A bounded cache of the existing 600px thumbnails. Paths include the identity
/// root; file metadata is read afresh so replacements and removals cannot go stale.
@MainActor final class ThumbnailCache: NSObject {
    static let shared = ThumbnailCache()
    private struct Stamp: Equatable {
        let size: Int
        let modified: Date
        let inode: UInt64
    }
    private struct Entry {
        let stamp: Stamp
        let image: UIImage
        let cost: Int
        var access: UInt64
    }
    private let byteLimit: Int
    private var entries: [String: Entry] = [:]
    private var clock: UInt64 = 0
    private(set) var byteCount = 0

    init(byteLimit: Int = 32 * 1024 * 1024) {
        self.byteLimit = max(0, byteLimit)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(removeAll),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    func image(at url: URL) -> UIImage? {
        let path = url.standardizedFileURL.path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int, let modified = attributes[.modificationDate] as? Date,
              let inode = attributes[.systemFileNumber] as? NSNumber else {
            remove(path); return nil
        }
        let stamp = Stamp(size: size, modified: modified, inode: inode.uint64Value)
        clock &+= 1
        if var entry = entries[path], entry.stamp == stamp {
            entry.access = clock; entries[path] = entry
            return entry.image
        }
        remove(path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 600,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cg), cost = cg.bytesPerRow * cg.height
        if cost <= byteLimit {
            while byteCount + cost > byteLimit || entries.count >= 64 {
                guard let oldest = entries.min(by: { $0.value.access < $1.value.access })?.key else { break }
                remove(oldest)
            }
            entries[path] = Entry(stamp: stamp, image: image, cost: cost, access: clock)
            byteCount += cost
        }
        return image
    }

    @objc func removeAll() { entries.removeAll(); byteCount = 0 }
    private func remove(_ path: String) {
        if let entry = entries.removeValue(forKey: path) { byteCount -= entry.cost }
    }
}
