import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import ImageIO

struct HouseMediaPage: View {
    let workspace: AppWorkspace
    let id: String
    @State private var type = "全部"
    @State private var picking = false
    @State private var selected: JSONValue?
    private var media: [JSONValue] { workspace.store.house(id)["media"].array.filter { type == "全部" || $0["type"].string == (type == "照片" ? "image" : "video") } }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack { ForEach(["全部", "照片", "视频"], id: \.self) { name in Button(name) { type = name }.buttonStyle(FilterChip(selected: type == name)) }; Spacer() }
                if media.isEmpty {
                    VStack(spacing: 12) { Text("还没有影像").font(.system(size: 16, weight: .semibold)); Text("把房间、细节和需要确认的地方拍下来。").font(.system(size: 13)).foregroundStyle(XJTheme.muted) }.padding(.top, 40)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(media, id: \.id) { item in
                        Button { selected = item } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    XJTheme.soft
                                    if item["type"].string == "image", let url = try? LocalMediaFiles.file(item["path"].string, in: workspace.store.records.directory), let image = thumbnail(url) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else { Text("▶ 视频").foregroundStyle(XJTheme.primary) }
                                }.frame(height: 152).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(item["caption"].string.isEmpty ? "＋ 添加影像备注" : item["caption"].string).font(.system(size: 12)).foregroundStyle(XJTheme.muted).lineLimit(2)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(16)
        }.safeAreaInset(edge: .bottom) {
            if !workspace.store.house(id)["archived"].bool {
                Button("拍照或录视频") { picking = true }.buttonStyle(XJButtonStyle(primary: true)).padding(16)
            }
        }.sheet(isPresented: $picking) { MediaPickerSheet(workspace: workspace, houseID: id) }
            .sheet(item: $selected) { MediaDetailPage(workspace: workspace, houseID: id, mediaID: $0.id) }
    }
}

func thumbnail(_ url: URL) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0,
        [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
    return UIImage(cgImage: cg)
}

private struct ImportedVideo: Transferable, Sendable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let url = FileManager.default.temporaryDirectory.appending(path: "xunju-picker-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: url)
            return ImportedVideo(url: url)
        }
    }
}

struct MediaPickerSheet: View {
    let workspace: AppWorkspace
    let houseID: String
    var fieldID = ""
    @State private var photo: PhotosPickerItem?
    @State private var camera = false
    @State private var busy = false
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PhotosPicker(selection: $photo, matching: .any(of: [.images, .videos]), preferredItemEncoding: .compatible) { Text("从相册选择照片或视频").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(XJButtonStyle(primary: true)).disabled(busy).accessibilityIdentifier("media.library")
                Button("拍照或录视频") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true }
                    else { error = "当前设备没有可用相机" }
                }.buttonStyle(XJButtonStyle(primary: false)).disabled(busy)
                Text("单个影像不超过 50 MiB").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                if busy { ProgressView("正在保存影像…") }
                if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger) }
                Spacer()
            }.padding(20).background(XJTheme.background).navigationTitle("添加影像").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(busy) } }
        }.onChange(of: photo) { _, item in if let item { load(item) } }
            .fullScreenCover(isPresented: $camera) {
                CameraPicker { result in
                    camera = false
                    switch result {
                    case .success(let payload): if payload.image != nil || payload.video != nil { save(image: payload.image, video: payload.video) }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            }
    }
    private func load(_ item: PhotosPickerItem) {
        guard !busy else { return }; busy = true; error = ""
        let store = workspace.store
        Task { @MainActor in
            defer { busy = false; photo = nil }
            do {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    guard let video = try await item.loadTransferable(type: ImportedVideo.self) else { throw CoreFailure(message: "视频读取失败") }
                    defer { try? FileManager.default.removeItem(at: video.url) }
                    try await persist(image: nil, video: video.url, store: store)
                } else {
                    guard let data = try await item.loadTransferable(type: Data.self), data.count <= 50 * 1024 * 1024, let image = UIImage(data: data) else { throw CoreFailure(message: "照片无法读取或超过 50 MiB") }
                    try await persist(image: image, video: nil, store: store)
                }
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
    private func save(image: UIImage?, video: URL?) {
        busy = true; error = ""; let store = workspace.store
        Task { @MainActor in
            defer { busy = false }
            do { try await persist(image: image, video: video, store: store); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func persist(image: UIImage?, video: URL?, store: NativeStore) async throws {
        let mediaID = "m" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let relative = "media/\(mediaID).\(video == nil ? "jpg" : "mp4")"
        _ = try LocalMediaFiles.directory(in: store.records.directory, create: true)
        let destination = store.records.directory.appending(path: relative)
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: destination) } }
        var duration = 0.0
        if let video {
            let asset = AVURLAsset(url: video)
            duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration >= 0 else { throw CoreFailure(message: "视频时长无法读取") }
            guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw CoreFailure(message: "视频无法转换") }
            if #available(iOS 18.0, *) { try await export.export(to: destination, as: .mp4) }
            else {
                export.outputURL = destination; export.outputFileType = .mp4
                await export.export()
                guard export.status == .completed else { throw CoreFailure(message: "视频转换失败") }
            }
        } else {
            guard let image, let data = image.jpegData(compressionQuality: 0.9), data.count <= 50 * 1024 * 1024 else { throw CoreFailure(message: "照片无法保存或超过 50 MiB") }
            try data.write(to: destination, options: .atomic)
        }
        let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 50 * 1024 * 1024 else { throw CoreFailure(message: "影像超过 50 MiB，请选择较短视频") }
        guard workspace.store === store else { throw CoreFailure(message: "账号已变化，请重新添加影像") }
        try store.call("addMedia", ["id": .string(houseID), "value": .object(["id": .string(mediaID), "type": .string(video == nil ? "image" : "video"), "path": .string(relative), "fieldId": .string(fieldID), "caption": .string(""), "duration": .number(duration), "createdAt": .string(ISO8601DateFormatter().string(from: Date()))])])
        committed = true
    }
}

private struct CameraPayload { let image: UIImage?; let video: URL? }
private struct CameraPicker: UIViewControllerRepresentable {
    let complete: (Result<CameraPayload, Error>) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? [UTType.image.identifier]
        picker.videoQuality = .typeHigh; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(complete: complete) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let complete: (Result<CameraPayload, Error>) -> Void
        init(complete: @escaping (Result<CameraPayload, Error>) -> Void) { self.complete = complete }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { complete(.success(CameraPayload(image: nil, video: nil))) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            complete(.success(CameraPayload(image: info[.originalImage] as? UIImage, video: info[.mediaURL] as? URL)))
        }
    }
}

private struct MediaDetailPage: View {
    let workspace: AppWorkspace
    let houseID: String
    let mediaID: String
    @State private var note = false
    @State private var linking = false
    @State private var deleting = false
    @State private var targets: [JSONValue] = []
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    private var media: JSONValue { workspace.store.house(houseID)["media"].array.first { $0.id == mediaID } ?? .null }
    private var readonly: Bool { workspace.store.house(houseID)["archived"].bool }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let url = try? LocalMediaFiles.file(media["path"].string, in: workspace.store.records.directory) {
                        if media["type"].string == "video" { VideoPlayer(player: AVPlayer(url: url)).frame(height: 320) }
                        else if let image = UIImage(contentsOfFile: url.path) { Image(uiImage: image).resizable().scaledToFit() }
                    }
                    Text(media["caption"].string).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                    if !readonly {
                        Button("编辑影像备注") { note = true }.buttonStyle(XJButtonStyle(primary: false))
                        Button("关联检查项") { linking = true }.buttonStyle(XJButtonStyle(primary: false))
                        Button("删除影像", role: .destructive) { deleting = true }
                    }
                }.padding(16)
            }.navigationTitle("影像").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } }
                .onAppear { workspace.perform { targets = try workspace.store.call("targets", ["id": .string(houseID)]).array } }
                .sheet(isPresented: $note) {
                    NoteEditor(title: "影像备注", text: media["caption"].string) { value in
                        try workspace.store.call("editMedia", ["id": .string(houseID), "field": .string(mediaID), "property": .string("caption"), "value": .string(value)])
                    }
                }
                .sheet(isPresented: $linking) {
                    NavigationStack {
                        List {
                            Button("不关联检查项") { link("") }
                            ForEach(targets.filter { search.isEmpty || $0["label"].string.localizedCaseInsensitiveContains(search) }, id: \.id) { target in Button(target["label"].string) { link(target.id) } }
                        }.searchable(text: $search, prompt: "搜索检查项").navigationTitle("关联检查项")
                            .toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } }
                    }
                }
                .confirmationDialog("删除这条影像？", isPresented: $deleting, titleVisibility: .visible) {
                    Button("删除影像", role: .destructive) {
                        if workspace.perform({ try workspace.store.call("removeMedia", ["id": .string(houseID), "field": .string(mediaID)]) }) { dismiss() }
                    }
                }
        }
    }
    private func link(_ field: String) {
        if workspace.perform({ try workspace.store.call("editMedia", ["id": .string(houseID), "field": .string(mediaID), "property": .string("fieldId"), "value": .string(field)]) }) { linking = false }
    }
}

@MainActor func houseCover(_ house: HouseSummary, store: NativeStore) -> UIImage? {
    guard !house.cover.isEmpty, let url = try? LocalMediaFiles.file(house.cover, in: store.records.directory) else { return nil }
    return thumbnail(url)
}
