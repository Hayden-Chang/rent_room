import Foundation

enum ExampleHouseMedia {
    // Called only by the store's first-installation branch, before its first save.
    static func prepare(in root: URL) throws {
        _ = try LocalMediaFiles.directory(in: root, create: true)
        for name in ["example-metro-v1", "example-sunny-v1"] {
            guard let source = Bundle.main.url(forResource: name, withExtension: "jpg") else {
                throw CoreFailure(message: "示例照片资源缺失")
            }
            let destination = try LocalMediaFiles.file("media/\(name).jpg", in: root)
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }
}
