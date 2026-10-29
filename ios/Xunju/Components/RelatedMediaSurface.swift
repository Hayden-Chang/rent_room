import SwiftUI

struct FieldMediaStrip: View {
    let items: [MediaTile]
    let preview: (MediaTile) -> Void
    let all: () -> Void
    var body: some View {
        if !items.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(items.prefix(3))) { item in
                    Button { preview(item) } label: {
                        if item.kind == .image { MediaThumbnail(item: item, height: 44, radius: 6, showsRelation: false) }
                        else { Text("▶ 视频").font(.system(size: 10)).foregroundStyle(XJTheme.primary).frame(width: 44, height: 44).background(XJTheme.soft) }
                    }.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain).contentShape(Rectangle()).accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton).accessibilityAction { preview(item) }
                        .accessibilityLabel(item.kind == .image ? "预览关联照片" : "播放关联视频")
                        .accessibilityIdentifier("related.preview.\(item.id)")
                }
                if items.count > 3 {
                    Button("+\(items.count - 3)", action: all).font(.system(size: 10)).foregroundStyle(XJTheme.primary)
                        .frame(width: 44, height: 44).background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain).accessibilityLabel("查看全部 \(items.count) 个关联影像")
                        .accessibilityIdentifier("related.all")
                }
                Spacer(minLength: 0)
            }.padding(.top, 8)
        }
    }
}

struct ManualIssueCard: View {
    let id: String
    let title: String
    let note: String
    let media: [MediaTile]
    let resolved: Bool
    var readonly = false
    let resolve: () -> Void
    let open: () -> Void
    let preview: (MediaTile) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: open) { Text(title).font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                    .buttonStyle(.plain).accessibilityIdentifier("manualIssue.\(id).open")
                Button(resolved ? "已解决" : "待跟进", action: resolve)
                    .font(.system(size: 13)).padding(.horizontal, 12).frame(minHeight: 44)
                    .foregroundStyle(resolved ? XJTheme.primary : XJTheme.danger)
                    .background(resolved ? XJTheme.soft : XJTheme.dangerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10)).buttonStyle(.plain).disabled(readonly)
                    .accessibilityIdentifier("manualIssue.\(id).resolve")
            }
            if !note.isEmpty {
                Button(action: open) { Text(note).font(.system(size: 14)).lineSpacing(6)
                    .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(.top, 10).buttonStyle(.plain)
            }
            if !media.isEmpty {
                VStack(spacing: 8) {
                    ForEach(IssueMediaRows.arrange(media), id: \.first!.id) { row in
                        if row.first?.kind == .video, let item = row.first {
                            InlineMediaVideo(url: item.url).clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityIdentifier("manualIssue.\(id).video.\(item.id)")
                        } else {
                            HStack(spacing: 8) {
                                ForEach(row) { item in
                                    Button { preview(item) } label: { MediaThumbnail(item: item, height: 96, radius: 8, showsRelation: false) }
                                        .buttonStyle(.plain).contentShape(Rectangle()).accessibilityElement(children: .ignore)
                                        .accessibilityAddTraits(.isButton).accessibilityAction { preview(item) }.accessibilityLabel("预览问题照片")
                                        .accessibilityIdentifier("manualIssue.\(id).preview.\(item.id)")
                                }
                                ForEach(0..<(3 - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                            }
                        }
                    }
                }.padding(.top, 12)
            }
            Button(action: open) {
                Text((media.isEmpty ? "" : "\(media.count) 个影像 · ") + (readonly ? "查看详情 ›" : "查看 / 编辑 ›"))
                    .font(.system(size: 12)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.top, 10).buttonStyle(.plain).accessibilityIdentifier("manualIssue.\(id).details")
        }.padding(16).foregroundStyle(XJTheme.ink)
            .background { Button(action: open) { Color.white }.buttonStyle(.plain).accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct AutomaticIssueCard<Content: View>: View {
    let category: String
    @ViewBuilder var content: Content
    var body: some View {
        XJCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(category).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                content
            }
        }
    }
}
