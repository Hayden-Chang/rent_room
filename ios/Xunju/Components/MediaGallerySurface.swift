import SwiftUI
import AVKit

struct MediaTile: Identifiable, Equatable {
    enum Kind: String { case image, video }
    let id: String
    let kind: Kind
    let url: URL?
    var caption = ""
    var relation = ""
}

enum MediaFilter: String, CaseIterable {
    case all = "全部", images = "照片", videos = "视频"
    func includes(_ item: MediaTile) -> Bool {
        self == .all || (self == .images && item.kind == .image) || (self == .videos && item.kind == .video)
    }
}

// Videos consume a full row without reordering the user's attachments.
enum IssueMediaRows {
    static func arrange(_ items: [MediaTile]) -> [[MediaTile]] {
        var rows: [[MediaTile]] = [], images: [MediaTile] = []
        for item in items {
            if item.kind == .video {
                if !images.isEmpty { rows.append(images); images = [] }
                rows.append([item])
            } else {
                images.append(item)
                if images.count == 3 { rows.append(images); images = [] }
            }
        }
        if !images.isEmpty { rows.append(images) }
        return rows
    }
}

struct MediaThumbnail: View {
    let item: MediaTile
    var height: CGFloat = 114
    var radius: CGFloat = 12
    var showsRelation = true
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                XJTheme.soft
                if item.kind == .image, let url = item.url, let image = thumbnail(url) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: height).clipped()
                } else if item.kind == .video {
                    VStack(spacing: 4) {
                        Text("▶").font(.system(size: 30))
                        Text("视频").font(.system(size: 11))
                    }.foregroundStyle(XJTheme.primary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo").foregroundStyle(XJTheme.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if showsRelation && !item.relation.isEmpty {
                    Text(item.relation).font(.system(size: 10)).lineLimit(1)
                        .foregroundStyle(.white).padding(4).frame(maxWidth: .infinity)
                        .background(XJTheme.ink.opacity(0.53))
                }
            }.frame(width: geometry.size.width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: radius))
        }.frame(height: height).contentShape(Rectangle()).accessibilityHidden(true)
    }
}

struct MediaGallerySurface: View {
    let items: [MediaTile]
    @Binding var filter: MediaFilter
    var readonly = false
    let preview: (MediaTile) -> Void
    let caption: (MediaTile) -> Void
    private var visible: [MediaTile] { items.filter(filter.includes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(MediaFilter.allCases, id: \.self) { value in
                    Button(value.rawValue) { filter = value }
                        .font(.system(size: 13)).padding(.horizontal, 18).frame(minHeight: 36)
                        .foregroundStyle(filter == value ? XJTheme.primary : XJTheme.ink)
                        .background(filter == value ? XJTheme.soft : .white)
                        .clipShape(Capsule()).buttonStyle(.plain)
                        .accessibilityIdentifier("gallery.filter.\(value.rawValue)")
                        .accessibilityAddTraits(filter == value ? .isSelected : [])
                }
            }
            if visible.isEmpty {
                VStack(spacing: 12) {
                    Text("还没有影像").font(.system(size: 17, weight: .semibold)).frame(height: 25.5)
                    Text("把房间、细节和需要确认的地方拍下来。")
                        .font(.system(size: 14)).foregroundStyle(XJTheme.muted).frame(height: 21)
                }.frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 56)
                    .accessibilityIdentifier("gallery.empty")
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3), alignment: .leading, spacing: 16) {
                    ForEach(visible) { item in
                        VStack(spacing: 0) {
                            Button { preview(item) } label: { MediaThumbnail(item: item) }
                                .buttonStyle(.plain).contentShape(Rectangle()).accessibilityElement(children: .ignore)
                                .accessibilityAddTraits(.isButton).accessibilityAction { preview(item) }
                                .accessibilityLabel(item.kind == .image ? "预览照片" : "播放视频")
                                .accessibilityIdentifier("gallery.preview.\(item.id)")
                            if !readonly || !item.caption.isEmpty { Button { caption(item) } label: {
                                Text(item.caption.isEmpty ? "＋" : item.caption)
                                    .font(.system(size: item.caption.isEmpty ? 22 : 13))
                                    .foregroundStyle(item.caption.isEmpty ? XJTheme.muted : XJTheme.ink)
                                    .multilineTextAlignment(.leading).padding(.horizontal, 2).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: item.caption.isEmpty ? .center : .topLeading)
                            }.buttonStyle(.plain).accessibilityLabel(item.caption.isEmpty ? "添加影像备注" : item.caption)
                                .accessibilityIdentifier("gallery.caption.\(item.id)")
                            }
                        }
                    }
                }
            }
        }.foregroundStyle(XJTheme.ink)
    }
}

struct InlineMediaVideo: View {
    let url: URL?
    @State private var player: AVPlayer?
    init(url: URL?) {
        self.url = url
        _player = State(initialValue: url.map(AVPlayer.init(url:)))
    }
    var body: some View {
        VideoPlayer(player: player).frame(height: 190).background(.black)
            .onDisappear { player?.pause() }
            .onChange(of: url) { _, value in player?.pause(); player = value.map(AVPlayer.init(url:)) }
    }
}
