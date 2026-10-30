import UIKit
import AVFoundation

@MainActor enum NativeMediaImport {
    static func stage(image: UIImage?, video: URL?, store: NativeStore, isCurrent: () -> Bool) async throws -> JSONValue {
        try Task.checkCancellation()
        guard isCurrent() else { throw CoreFailure(message: "账号已变化，请重新添加影像") }
        let id = "m" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let path = "media/\(id).\(video == nil ? "jpg" : "mp4")"
        _ = try LocalMediaFiles.directory(in: store.records.directory, create: true)
        let destination = try LocalMediaFiles.file(path, in: store.records.directory)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw CoreFailure(message: "影像文件名重复，请重试") }
        var staged = false
        defer { if !staged { try? FileManager.default.removeItem(at: destination) } }
        var duration = 0.0
        if let video {
            let source = try video.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard source.isRegularFile == true, let bytes = source.fileSize, bytes > 0, bytes <= 50 * 1024 * 1024 else {
                throw CoreFailure(message: "视频无法读取或超过 50 MiB")
            }
            let asset = AVURLAsset(url: video)
            duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration >= 0 else { throw CoreFailure(message: "视频时长无法读取") }
            try Task.checkCancellation()
            guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                throw CoreFailure(message: "视频无法转换")
            }
            if #available(iOS 18.0, *) { try await export.export(to: destination, as: .mp4) }
            else {
                export.outputURL = destination; export.outputFileType = .mp4
                await export.export()
                guard export.status == .completed else { throw CoreFailure(message: "视频转换失败") }
            }
        } else {
            guard let image else { throw CoreFailure(message: "照片无法保存或超过 50 MiB") }
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                try autoreleasepool {
                    guard let data = image.jpegData(compressionQuality: 0.9), data.count <= 50 * 1024 * 1024 else {
                        throw CoreFailure(message: "照片无法保存或超过 50 MiB")
                    }
                    try Task.checkCancellation()
                    try data.write(to: destination, options: .atomic)
                }
            }
            // Await the worker even on cancellation, so cleanup never races a
            // late file write. The final scope check still runs on the main actor.
            try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
        }
        try Task.checkCancellation()
        let bytes = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0, bytes <= 50 * 1024 * 1024 else { throw CoreFailure(message: "影像超过 50 MiB，请选择较短视频") }
        guard isCurrent() else { throw CoreFailure(message: "账号已变化，请重新添加影像") }
        staged = true
        return .object(["id": .string(id), "type": .string(video == nil ? "image" : "video"), "path": .string(path),
                        "fieldId": .string(""), "caption": .string(""), "duration": .number(duration),
                        "createdAt": .string(ISO8601DateFormatter().string(from: Date()))])
    }
}

// A separate opt-in flag is required in addition to an isolated test identity.
enum MediaImportFixture {
    static func enabled(_ arguments: [String]) -> Bool {
        #if DEBUG
        guard arguments.contains("--media-import-fixture"), let index = arguments.firstIndex(of: "--business-test"),
              arguments.indices.contains(index + 1) else { return false }
        return UUID(uuidString: arguments[index + 1]) != nil
        #else
        return false
        #endif
    }
}
