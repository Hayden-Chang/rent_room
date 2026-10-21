import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import ImageIO

struct HouseMediaPage: View {
    let workspace: AppWorkspace
    let id: String
    @State private var filter: MediaFilter = .all
    @State private var picking = false
    @State private var selected: JSONValue?
    @State private var caption: JSONValue?
    @State private var media: [JSONValue] = []
    private var readonly: Bool { workspace.store.house(id)["archived"].bool }
    var body: some View {
        ScrollView {
            MediaGallerySurface(items: media.map { mediaTile($0, store: workspace.store) }, filter: $filter, readonly: readonly,
                preview: { tile in selected = media.first { $0.id == tile.id } },
                caption: { tile in caption = media.first { $0.id == tile.id } }).padding(16)
        }.safeAreaInset(edge: .bottom) {
            if !readonly {
                Button("拍照或录视频") { picking = true }.buttonStyle(XJButtonStyle(primary: true)).padding(16).accessibilityIdentifier("media.add")
            }
        }.onAppear(perform: refresh)
            .onChange(of: workspace.store.status.revision) { _, _ in refresh() }
            .fullScreenCover(isPresented: $picking) { MediaPickerSheet(workspace: workspace, houseID: id) }
            .sheet(item: $selected) { MediaDetailPage(workspace: workspace, houseID: id, mediaID: $0.id) }
            .sheet(item: $caption) { item in
                NoteEditor(title: "影像备注", text: item["caption"].string, readonly: readonly) { text in
                    try workspace.store.call("editMedia", ["id": .string(id), "field": .string(item.id), "property": .string("caption"), "value": .string(text)])
                }
            }
    }
    private func refresh() { workspace.perform { media = try workspace.store.call("media", ["id": .string(id)]).array } }
}

@MainActor func mediaTile(_ value: JSONValue, store: NativeStore) -> MediaTile {
    MediaTile(id: value.id, kind: value["type"].string == "video" ? .video : .image,
              url: try? LocalMediaFiles.file(value["path"].string, in: store.records.directory),
              caption: value["caption"].string,
              relation: !value["issueTitle"].string.isEmpty ? "问题 · " + value["issueTitle"].string : value["fieldId"].string.isEmpty ? "房源影像" : "已关联检查项")
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
    var stage: ((JSONValue) throws -> Void)? = nil
    @State private var photo: PhotosPickerItem?
    @State private var library = false
    @State private var camera = false
    @State private var busy = false
    @State private var importTask: Task<Void, Never>?
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            MPSourceSheet(close: { if !busy { dismiss() } }, library: { library = true }, camera: {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true }
                    else { error = "当前设备没有可用相机" }
                }).allowsHitTesting(!busy).accessibilityElement(children: .contain).accessibilityIdentifier("media.source").accessibilityHidden(busy)
            if busy {
                ProgressView("正在保存影像…").padding(24).background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            #if DEBUG
            if MediaImportFixture.enabled(ProcessInfo.processInfo.arguments) {
                VStack {
                    HStack(spacing: 20) {
                        Button("导入测试照片") { fixture(video: false) }.accessibilityIdentifier("media.fixture.image")
                        Button("导入测试视频") { fixture(video: true) }.accessibilityIdentifier("media.fixture.video")
                    }.padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).disabled(busy)
                    Spacer()
                }
            }
            #endif
        }.presentationBackground(.clear).interactiveDismissDisabled(busy)
            .photosPicker(isPresented: $library, selection: $photo, matching: .any(of: [.images, .videos]), preferredItemEncoding: .compatible)
            .alert("无法添加影像", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) {
                Button("知道了") { error = "" }
            } message: { Text(error) }
            .onDisappear { importTask?.cancel() }
            .onChange(of: photo) { _, item in if let item { load(item) } }
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
        importTask = Task { @MainActor in
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
        importTask = Task { @MainActor in
            defer { busy = false }
            do { try await persist(image: image, video: video, store: store); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func persist(image: UIImage?, video: URL?, store: NativeStore) async throws {
        let item = try await NativeMediaImport.stage(image: image, video: video, store: store, isCurrent: { workspace.store === store })
            .setting("fieldId", to: .string(fieldID))
        var accepted = false
        defer { if !accepted { LocalMediaReferences.discard([item["path"].string], in: store) } }
        try Task.checkCancellation()
        if let stage { try stage(item) }
        else { try store.call("addMedia", ["id": .string(houseID), "value": item]) }
        accepted = true
    }
    #if DEBUG
    private func fixture(video: Bool) {
        guard !busy, MediaImportFixture.enabled(ProcessInfo.processInfo.arguments) else { return }
        busy = true; error = ""; let store = workspace.store
        importTask = Task { @MainActor in
            defer { busy = false }
            do {
                let fixtures = try MediaReviewFixtures.make()
                defer { if let root = fixtures.first?.url?.deletingLastPathComponent() { try? FileManager.default.removeItem(at: root) } }
                guard let source = fixtures.first(where: { $0.kind == (video ? .video : .image) })?.url else { throw CoreFailure(message: "测试影像缺失") }
                try await persist(image: video ? nil : UIImage(contentsOfFile: source.path), video: video ? source : nil, store: store)
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
    #endif

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
