import SwiftUI
import AVKit

struct MPMediaItem: Identifiable {
    let id: String
    var tile: MediaTile
    var duration: Double = 0
}

struct MPMediaGallery: View {
    let items: [MPMediaItem]
    @Binding var filter: MediaFilter
    var readonly = false
    let preview: (String) -> Void, caption: (String) -> Void, manage: (String) -> Void, capture: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(MediaFilter.allCases, id: \.self) { value in
                        Button(value.rawValue) { filter = value }.font(.system(size: 13)).padding(.horizontal, 18).frame(minHeight: 36)
                            .foregroundStyle(filter == value ? XJTheme.primary : XJTheme.ink).background(filter == value ? XJTheme.soft : .white)
                            .clipShape(Capsule()).buttonStyle(.plain).accessibilityIdentifier("mp.media.filter.\(value.rawValue)")
                    }
                }
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Text("还没有影像").font(.system(size: 17, weight: .semibold))
                        Text("把房间、细节和需要确认的地方拍下来。").font(.system(size: 14)).foregroundStyle(XJTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 56)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3), alignment: .leading, spacing: 16) {
                    ForEach(items.filter { filter.includes($0.tile) }) { item in
                        VStack(spacing: 0) {
                            Button { preview(item.id) } label: { mediaThumbnail(item) }.buttonStyle(.plain)
                                .onLongPressGesture { if !readonly { manage(item.id) } }
                                .accessibilityLabel(item.tile.kind == .video ? "播放视频" : "预览照片").accessibilityIdentifier("mp.media.preview.\(item.id)")
                            if readonly {
                                if !item.tile.caption.isEmpty { Text(item.tile.caption).font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading).padding(.vertical, 8) }
                            } else {
                                Button { caption(item.id) } label: {
                                    Text(item.tile.caption.isEmpty ? "＋" : item.tile.caption).font(.system(size: item.tile.caption.isEmpty ? 22 : 13))
                                        .foregroundStyle(item.tile.caption.isEmpty ? XJTheme.muted : XJTheme.ink)
                                        .multilineTextAlignment(.leading).padding(.horizontal, 2).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: item.tile.caption.isEmpty ? .center : .topLeading)
                                }.buttonStyle(.plain).accessibilityIdentifier("mp.media.caption.\(item.id)")
                            }
                        }
                    }
                }
            }.padding(16).padding(.bottom, 80)
        }.overlay(alignment: .bottomTrailing) {
            if !readonly { MPFloatingButton(icon: "camera", label: "拍照或录视频", action: capture).padding(16).accessibilityIdentifier("mp.media.capture") }
        }
    }
    private func mediaThumbnail(_ item: MPMediaItem) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                XJTheme.soft
                if item.tile.kind == .image, let url = item.tile.url, let image = thumbnail(url) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: 114).clipped()
                } else if item.tile.kind == .video {
                    VStack(spacing: 4) {
                        Text("▶").font(.system(size: 30))
                        Text("视频 \(String(format: "%g", item.duration))s").font(.system(size: 11))
                    }.foregroundStyle(XJTheme.primary).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Text(item.tile.relation).font(.system(size: 10)).foregroundStyle(.white).lineLimit(1).padding(4).frame(maxWidth: .infinity).background(XJTheme.ink.opacity(0.53))
            }.frame(width: geometry.size.width, height: 114).clipShape(RoundedRectangle(cornerRadius: 12))
        }.frame(height: 114)
    }
}

struct MPMediaPreview: View {
    let items: [MPMediaItem]
    @Binding var selected: String
    let close: () -> Void
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selected) {
                ForEach(items) { item in
                    Group {
                        if item.tile.kind == .video { InlineMediaVideo(url: item.tile.url) }
                        else if let url = item.tile.url, let image = UIImage(contentsOfFile: url.path) { MPZoomImage(image: image).accessibilityIdentifier("mp.preview.image.\(item.id)") }
                    }.tag(item.id)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never)).accessibilityIdentifier("mp.preview.pages")
            HStack {
                Button(action: close) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("关闭预览")
                Spacer()
                Text("\((items.firstIndex { $0.id == selected } ?? 0) + 1) / \(items.count)").font(.system(size: 14)).accessibilityIdentifier("mp.preview.index")
                Spacer(); Color.clear.frame(width: 44, height: 44)
            }.foregroundStyle(.white).background(.black.opacity(0.4))
        }
    }
}

struct MPZoomImage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ImageScroll {
        let scroll = ImageScroll()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 4
        scroll.showsHorizontalScrollIndicator = false; scroll.showsVerticalScrollIndicator = false
        scroll.picture.contentMode = .scaleAspectFit; scroll.addSubview(scroll.picture)
        return scroll
    }
    func updateUIView(_ scroll: ImageScroll, context: Context) { scroll.picture.image = image; scroll.setNeedsLayout() }
    final class ImageScroll: UIScrollView {
        let picture = UIImageView()
        override func layoutSubviews() {
            super.layoutSubviews()
            if zoomScale == 1 { picture.frame = bounds; contentSize = bounds.size }
        }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ImageScroll)?.picture }
    }
}

struct MPAssociationSheet: View {
    let items: [(String, String)]
    @Binding var query: String
    let close: () -> Void, select: (String) -> Void
    var body: some View {
        MPBottomSheet(close: close) {
            VStack(alignment: .leading, spacing: 16) {
                Text("关联检查项").font(.system(size: 17, weight: .semibold))
                TextField("搜索检查项", text: $query).font(.system(size: 14)).padding(12).background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(items.filter { query.isEmpty || $0.1.localizedCaseInsensitiveContains(query) }, id: \.0) { id, label in
                            Button { select(id) } label: { Text(label).font(.system(size: 14)).frame(maxWidth: .infinity, minHeight: 49, alignment: .leading) }
                                .buttonStyle(.plain).overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
                        }
                    }
                }.frame(height: 300)
            }
        }
    }
}

struct MPSourceSheet: View {
    let close: () -> Void, library: () -> Void, camera: () -> Void
    var body: some View {
        MPActionMenu(title: "", actions: [("从相册选择照片或视频", false, library), ("拍照或录视频", false, camera)], close: close)
    }
}

struct MPSummarySurface: View {
    @Binding var decision: String
    @Binding var note: String
    var readonly = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("意向").font(.system(size: 14)).padding(.top, 8).padding(.bottom, 12)
                HStack(spacing: 0) {
                    ForEach(["考虑租住", "继续比较", "放弃"], id: \.self) { value in
                        Button { decision = decision == value ? "" : value } label: {
                            Text(value == "放弃" ? "放弃这套" : value).font(.system(size: 13, weight: decision == value ? .semibold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(decision == value ? .white : XJTheme.muted)
                                .background(decision == value ? XJTheme.primary : .clear).clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(readonly).opacity(readonly ? 0.45 : 1).accessibilityIdentifier("mp.summary.\(value)")
                            .accessibilityAddTraits(decision == value ? .isSelected : [])
                    }
                }.padding(3).frame(height: 52).background(.white).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(XJTheme.line))
                Text("备注").font(.system(size: 14)).padding(.top, 24).padding(.bottom, 12)
                ZStack(alignment: .topLeading) {
                    if note.isEmpty { Text("记录下你对这套房源的整体感受…").font(.system(size: 14)).foregroundStyle(XJTheme.muted).padding(16) }
                    TextEditor(text: $note).font(.system(size: 14)).scrollContentBackground(.hidden).padding(.horizontal, 11).padding(.vertical, 8)
                        .disabled(readonly).onChange(of: note) { note = String(note.prefix(10000)) }.accessibilityIdentifier("mp.summary.note")
                }.frame(height: 200).background(.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(XJTheme.line))
            }.padding(16)
        }
    }
}

struct MPIssueEditorSurface: View {
    @Binding var title: String
    @Binding var note: String
    let media: [MediaTile]
    var readonly = false, busy = false, error = "", titleError = ""
    let preview: (MediaTile) -> Void, remove: (MediaTile) -> Void, add: () -> Void, cancel: () -> Void, save: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if readonly { Text("房源已归档，问题只读").font(.system(size: 12)).foregroundStyle(XJTheme.primary).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.soft) }
                    MPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) { Text("标题").font(.system(size: 15, weight: .semibold)); Text("必填").font(.system(size: 11)).foregroundStyle(XJTheme.danger).padding(.horizontal, 6).padding(.vertical, 2).background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 4)) }
                            TextField("例如：卧室窗户关不严", text: $title).font(.system(size: 14)).padding(.horizontal, 12).frame(height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(titleError.isEmpty ? XJTheme.line : XJTheme.danger)).disabled(readonly || busy)
                                .onChange(of: title) { title = String(title.prefix(200)) }.accessibilityIdentifier("mp.issue.title")
                            if !titleError.isEmpty { Text(titleError).font(.system(size: 12)).foregroundStyle(XJTheme.danger).accessibilityIdentifier("mp.issue.title-error") }
                            HStack(spacing: 8) { Text("备注").font(.system(size: 15, weight: .semibold)); Text("选填").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }.padding(.top, 12)
                            ZStack(alignment: .topLeading) {
                                if note.isEmpty { Text("补充问题详情、需要确认或跟进的事项…").font(.system(size: 14)).foregroundStyle(XJTheme.muted).padding(12).allowsHitTesting(false) }
                                MPGrowingText(text: $note, readonly: readonly || busy).accessibilityIdentifier("mp.issue.note")
                            }.background(XJTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    MPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) { Text("影像").font(.system(size: 15, weight: .semibold)); Text("选填 · 照片或视频").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                            if media.isEmpty && readonly { Text("未添加影像").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                            ForEach(IssueMediaRows.arrange(media), id: \.first!.id) { row in
                                HStack(alignment: .top, spacing: 10) {
                                    ForEach(row) { item in
                                        VStack(spacing: 0) {
                                            if item.kind == .video { InlineMediaVideo(url: item.url) }
                                            else { Button { preview(item) } label: { MediaThumbnail(item: item, height: 104, radius: 8, showsRelation: false) }.buttonStyle(.plain) }
                                            if !readonly { Button("移除") { remove(item) }.font(.system(size: 12)).foregroundStyle(XJTheme.danger).frame(maxWidth: .infinity, minHeight: 44).background(XJTheme.background).disabled(busy) }
                                        }.clipShape(RoundedRectangle(cornerRadius: 8)).padding(.bottom, 12)
                                    }
                                    if row.first?.kind != .video { ForEach(0..<(3 - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) } }
                                }
                            }
                            if !readonly { Button("＋ 添加照片 / 视频", action: add).buttonStyle(MPButtonStyle(kind: .soft)).disabled(busy) }
                        }
                    }
                    if !error.isEmpty { Text(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.dangerBackground) }
                }.padding(16)
            }
            GeometryReader { geometry in
                let unit = max(0, geometry.size.width - 12) / 3
                HStack(spacing: 12) {
                    Button(readonly ? "返回" : "取消", action: cancel).buttonStyle(MPButtonStyle()).frame(width: readonly ? geometry.size.width : unit)
                    if !readonly { Button("保存问题", action: save).buttonStyle(MPButtonStyle(kind: .primary)).frame(width: unit * 2).accessibilityIdentifier("mp.issue.save") }
                }
            }.frame(height: 44).disabled(busy).padding(.horizontal, 16).padding(.vertical, 12).background(.white).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
        }
    }
}

struct MPGrowingText: UIViewRepresentable {
    @Binding var text: String
    var readonly = false
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(); view.delegate = context.coordinator; view.isScrollEnabled = false
        view.font = .systemFont(ofSize: 14); view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.accessibilityIdentifier = "mp.growing-text"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) { if view.text != text { view.text = text }; view.isEditable = !readonly; context.coordinator.text = $text }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return CGSize(width: width, height: max(160, uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) { text.wrappedValue = String(textView.text.prefix(10000)); if textView.text != text.wrappedValue { textView.text = text.wrappedValue } }
    }
}
