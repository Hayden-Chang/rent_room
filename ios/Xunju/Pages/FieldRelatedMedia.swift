import SwiftUI

struct FieldRelatedMedia: View {
    let workspace: AppWorkspace
    let houseID: String
    let fieldID: String
    @State private var preview: MediaTile?
    @State private var all = false
    private var items: [MediaTile] {
        workspace.store.house(houseID)["media"].array.filter { $0["fieldId"].string == fieldID }
            .map { mediaTile($0, store: workspace.store) }
    }
    var body: some View {
        FieldMediaStrip(items: items, preview: { preview = $0 }, all: { all = true })
            .accessibilityElement(children: .contain).accessibilityIdentifier("related.\(fieldID)")
            .sheet(item: $preview) { MediaPreviewSheet(item: $0) }
            .sheet(isPresented: $all) { RelatedMediaGalleryPage(workspace: workspace, houseID: houseID, fieldID: fieldID) }
    }
}

private struct RelatedMediaGalleryPage: View {
    let workspace: AppWorkspace
    let houseID: String
    let fieldID: String
    @State private var filter: MediaFilter = .all
    @State private var preview: MediaTile?
    @State private var caption: MediaTile?
    private var readonly: Bool { workspace.store.house(houseID)["archived"].bool }
    private var items: [MediaTile] {
        workspace.store.house(houseID)["media"].array.filter { $0["fieldId"].string == fieldID }
            .map { mediaTile($0, store: workspace.store) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                MediaGallerySurface(items: items, filter: $filter, readonly: readonly,
                    preview: { preview = $0 }, caption: { caption = $0 }).padding(16)
            }.background(XJTheme.background).navigationTitle("全部关联影像").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } }
                .sheet(item: $preview) { MediaPreviewSheet(item: $0) }
                .sheet(item: $caption) { item in
                    NoteEditor(title: "影像备注", text: item.caption, readonly: readonly) { text in
                        try workspace.store.call("editMedia", ["id": .string(houseID), "field": .string(item.id), "property": .string("caption"), "value": .string(text)])
                    }
                }
        }
    }
}

struct MediaPreviewSheet: View {
    let item: MediaTile
    var imageIdentifier = "media.preview.image"
    var body: some View {
        NavigationStack {
            Group {
                if item.kind == .video { InlineMediaVideo(url: item.url) }
                else if let url = item.url, let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier(imageIdentifier)
                }
            }.padding(16).navigationTitle("影像预览").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } }
        }
    }
}
