import SwiftUI

struct IssueEditorSurface: View {
    @Binding var title: String
    @Binding var note: String
    let media: [MediaTile]
    @Binding var titleError: String
    @Binding var error: String
    var readonly = false
    var selecting = false
    var saving = false
    var dirty = false
    let addMedia: () -> Void
    let removeMedia: (MediaTile) -> Void
    let preview: (MediaTile) -> Void
    let cancel: () -> Void
    let save: () -> Void
    @State private var discarding = false
    @FocusState private var focused: Focus?
    private enum Focus { case title, note }
    private var busy: Bool { selecting || saving }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if readonly {
                    Text("房源已归档，问题只读").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                }
                XJCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Text("标题").font(.system(size: 15, weight: .semibold))
                            Text("必填").font(.system(size: 11)).foregroundStyle(XJTheme.danger)
                                .padding(.vertical, 2).padding(.horizontal, 6).background(XJTheme.dangerBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }.padding(.bottom, 12)
                        TextField("例如：卧室窗户关不严", text: limited($title, to: 200, isTitle: true))
                            .font(.system(size: 14)).padding(.horizontal, 12).frame(height: 48)
                            .background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(titleError.isEmpty ? XJTheme.line : XJTheme.danger))
                            .focused($focused, equals: .title).disabled(readonly || busy)
                            .accessibilityIdentifier("issueEditor.title")
                        if !titleError.isEmpty {
                            Text(titleError).font(.system(size: 12)).foregroundStyle(XJTheme.danger)
                                .padding(.top, 6).accessibilityIdentifier("issueEditor.titleError")
                        }
                        label("备注", hint: "选填").padding(.top, 24).padding(.bottom, 12)
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("补充问题详情、需要确认或跟进的事项…")
                                    .foregroundStyle(XJTheme.muted).padding(.horizontal, 12).padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: limited($note, to: 10000)).scrollContentBackground(.hidden)
                                .padding(.horizontal, 7).padding(.vertical, 4).frame(minHeight: 160)
                                .focused($focused, equals: .note).disabled(readonly || busy)
                                .accessibilityIdentifier("issueEditor.note")
                        }.font(.system(size: 14)).lineSpacing(4).background(XJTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                XJCard {
                    VStack(alignment: .leading, spacing: 12) {
                        label("影像", hint: "选填 · 照片或视频")
                        if media.isEmpty && readonly {
                            Text("未添加影像").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                        }
                        VStack(spacing: 10) {
                            ForEach(IssueMediaRows.arrange(media), id: \.first!.id) { row in
                                if row.first?.kind == .video, let item = row.first {
                                    mediaCell(item)
                                } else {
                                    HStack(alignment: .top, spacing: 10) {
                                        ForEach(row) { mediaCell($0).frame(maxWidth: .infinity) }
                                        ForEach(0..<(3 - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                                    }
                                }
                            }
                        }
                        if !readonly {
                            Button(action: addMedia) {
                                HStack { if selecting { ProgressView() }; Text("＋ 添加照片 / 视频") }
                            }.buttonStyle(XJButtonStyle())
                                .disabled(busy).accessibilityIdentifier("issueEditor.addMedia")
                        }
                    }
                }
                if !error.isEmpty {
                    Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger)
                        .padding(.vertical, 12).padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("issueEditor.error")
                }
            }.padding(16)
        }.background(XJTheme.background).foregroundStyle(XJTheme.ink)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("完成") { focused = nil }
                }
            }
            .alert("放弃修改？", isPresented: $discarding) {
                Button("放弃", role: .destructive, action: cancel)
                Button("继续编辑", role: .cancel) {}
            } message: { Text("尚未保存的文字和新增影像将被放弃。") }
    }

    private func label(_ text: String, hint: String) -> some View {
        HStack(spacing: 8) {
            Text(text).font(.system(size: 15, weight: .semibold))
            Text(hint).font(.system(size: 13)).foregroundStyle(XJTheme.muted)
        }
    }
    private func limited(_ binding: Binding<String>, to count: Int, isTitle: Bool = false) -> Binding<String> {
        // Limit typing only; opening an imported record never rewrites its text.
        Binding(get: { binding.wrappedValue }, set: {
            binding.wrappedValue = String($0.prefix(count)); error = ""
            if isTitle { titleError = "" }
        })
    }
    private func mediaCell(_ item: MediaTile) -> some View {
        VStack(spacing: 0) {
            if item.kind == .video {
                InlineMediaVideo(url: item.url).accessibilityIdentifier("issueEditor.video.\(item.id)")
            } else {
                Button { preview(item) } label: { MediaThumbnail(item: item, height: 104, radius: 8, showsRelation: false) }
                    .buttonStyle(.plain).contentShape(Rectangle()).accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton).accessibilityAction { preview(item) }.accessibilityLabel("预览影像")
                    .accessibilityIdentifier("issueEditor.preview.\(item.id)")
            }
            if !readonly {
                Button("移除") { removeMedia(item) }.font(.system(size: 12)).foregroundStyle(XJTheme.danger)
                    .frame(maxWidth: .infinity, minHeight: 44).background(XJTheme.background)
                    .buttonStyle(.plain).disabled(busy).accessibilityIdentifier("issueEditor.remove.\(item.id)")
            }
        }.clipShape(RoundedRectangle(cornerRadius: 8)).padding(.bottom, 12)
    }
    private var footer: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                Button(readonly ? "返回" : "取消") {
                    focused = nil
                    if dirty && !readonly { discarding = true } else { cancel() }
                }.buttonStyle(XJButtonStyle()).frame(width: readonly ? geometry.size.width : (geometry.size.width - 12) / 3)
                    .accessibilityIdentifier("issueEditor.cancel")
                if !readonly {
                    Button { focused = nil; save() } label: {
                        HStack { if saving { ProgressView().tint(.white) }; Text("保存问题") }
                    }.buttonStyle(XJButtonStyle(primary: true))
                        .accessibilityIdentifier("issueEditor.save")
                }
            }.disabled(busy)
        }.frame(height: 44).padding(.horizontal, 16).padding(.vertical, 12)
            .background(.white).overlay(alignment: .top) { Rectangle().fill(XJTheme.line).frame(height: 1) }
    }
}
