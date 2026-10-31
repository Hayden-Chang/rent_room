import SwiftUI
import AuthenticationServices

struct MPSwitch: View {
    @Binding var value: Bool
    var label: String
    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { value.toggle() } } label: {
            Capsule().fill(value ? XJTheme.primary : Color(red: 223/255, green: 226/255, blue: 232/255))
                .overlay(alignment: value ? .trailing : .leading) { Circle().fill(.white).frame(width: 26, height: 26).padding(3).shadow(color: .black.opacity(0.08), radius: 1) }
                .frame(width: 52, height: 32)
        }.buttonStyle(.plain).accessibilityLabel(AppCopy.text(label)).accessibilityValue(AppCopy.text(value ? "开启" : "关闭"))
    }
}

struct MPSettingsSurface: View {
    var authenticated: Bool
    @Binding var nickname: String
    var avatar: UIImage? = nil
    var status = "已通过 Apple 登录"
    var used = 0, limit = 2, archived = 0
    var workplace = "", version = "0.1.0"
    var accountReady = true, recoveryBlocked = false
    @Binding var onboarding: Bool
    let appleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let appleCompletion: (Result<ASAuthorization, Error>) -> Void
    var appleReady = false
    let avatarAction: () -> Void, nicknameCommit: () -> Void
    let capacity: () -> Void, openWorkplace: () -> Void, archive: () -> Void
    let importFile: () -> Void, export: () -> Void, permissions: () -> Void, logout: () -> Void
    var recover: () -> Void = {}
    @FocusState private var editing: Bool
    var body: some View {
        if !accountReady {
            AppText("正在确认登录状态…").font(.system(size: 14)).foregroundStyle(XJTheme.muted)
                .padding(.horizontal, 24).padding(.top, 64).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("mp.account.waiting")
        } else { ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if recoveryBlocked {
                    MPCard { MPMenuRow(title: "尝试恢复本机记录", action: recover).accessibilityIdentifier("mp.profile.recover") }
                }
                if !authenticated {
                    LoginEntryCard(used: used, limit: limit, appleReady: appleReady,
                        appleRequest: appleRequest,
                        appleCompletion: appleCompletion, capacity: capacity)
                } else { MPCard {
                    VStack(spacing: 0) {
                        if authenticated {
                            HStack(spacing: 14) {
                                Button(action: avatarAction) {
                                    Group {
                                        if let avatar { Image(uiImage: avatar).resizable().scaledToFill() }
                                        else { MPAccountIcon() }
                                    }.frame(width: 54, height: 54).background(XJTheme.soft).clipShape(Circle())
                                }.buttonStyle(.plain).accessibilityLabel(AppCopy.text("选择头像")).accessibilityIdentifier("mp.profile.avatar")
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField(AppCopy.text("昵称"), text: $nickname).font(.system(size: 20, weight: .semibold)).frame(height: 30)
                                        .focused($editing).onChange(of: nickname) { nickname = String(nickname.prefix(32)) }
                                        .onChange(of: editing) { if !editing { nicknameCommit() } }.accessibilityIdentifier("mp.profile.nickname")
                                    AppText(status).font(.system(size: 13)).foregroundStyle(XJTheme.primary)
                                }
                            }.padding(.bottom, 16)
                        }
                        XJTheme.line.frame(height: 1)
                        Button(action: capacity) {
                            HStack { AppText("房源容量"); Spacer(); AppText("\(used) / \(limit) 套 ›").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                                .font(.system(size: 14, weight: .medium)).padding(.top, 14)
                        }.buttonStyle(.plain)
                    }
                } }
                MPCard {
                    VStack(spacing: 0) {
                        MPMenuRow(title: "上班地点", detail: workplace.isEmpty ? "未设置" : workplace, action: openWorkplace)
                        MPMenuRow(title: "删除房源", detail: "\(archived) 套", action: archive)
                        HStack { AppText("操作引导").font(.system(size: 14, weight: .medium)); Spacer(); MPSwitch(value: $onboarding, label: "操作引导") }
                            .frame(minHeight: 60).overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
                    }
                }
                AppText("数据与备份").font(.system(size: 16, weight: .semibold)).padding(.top, 8)
                MPCard {
                    VStack(spacing: 0) {
                        MPMenuRow(title: "导入房源", action: importFile)
                        MPMenuRow(title: "导出房源", action: export)
                    }
                }
                MPCard { MPMenuRow(title: "权限管理", action: permissions) }
                MPCard {
                    HStack { AppText("版本"); Spacer(); AppText(version).foregroundStyle(XJTheme.muted) }.font(.system(size: 14)).frame(minHeight: 49)
                        .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
                }
                if authenticated {
                    Button(AppCopy.text("退出登录"), action: logout).font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.danger)
                        .frame(maxWidth: .infinity, minHeight: 48).background(.white).clipShape(RoundedRectangle(cornerRadius: 8)).padding(.top, 8)
                        .accessibilityIdentifier("mp.profile.logout")
                }
            }.padding(16).padding(.bottom, 16)
        } }
    }
}

enum MPConflictMode: String { case replace, copy }
struct MPTransferItem: Identifiable {
    let id: String, name: String, address: String
    var fields: Int, media: Int
    var archived = false
    var conflictName: String? = nil
}

enum MPTransferSelection {
    static func ready(items: [MPTransferItem], selected: Set<String>, modes: [String: MPConflictMode], exporting: Bool) -> Bool {
        let chosen = items.filter { selected.contains($0.id) }
        return !chosen.isEmpty && (exporting || chosen.allSatisfy { $0.conflictName == nil || modes[$0.id] != nil })
    }
}

struct MPTransferSurface: View {
    let exporting: Bool
    let items: [MPTransferItem]
    @Binding var selected: Set<String>
    @Binding var modes: [String: MPConflictMode]
    var fileName = "", busy = false, preparing = false, progress = "", error = "", retryShare = false
    let choose: () -> Void, cancel: () -> Void, commit: () -> Void
    private var ready: Bool { MPTransferSelection.ready(items: items, selected: selected, modes: modes, exporting: exporting) }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AppText(exporting ? "选择要导出的房源" : "选择要导入的房源").font(.system(size: 22, weight: .semibold))
                    if !exporting {
                            VStack(spacing: 0) {
                                Text(verbatim: fileName.isEmpty ? AppCopy.text("尚未选择 ZIP 文件") : fileName).font(.system(size: 12)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                                Button(AppCopy.text(fileName.isEmpty ? "选择 ZIP 文件" : "重新选择 ZIP"), action: choose).font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.primary).frame(minHeight: 44)
                            }.padding(.horizontal, 16).padding(.vertical, 12).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !error.isEmpty { AppText(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    if !items.isEmpty {
                        HStack {
                            AppText("共 \(items.count) 套，已选 \(selected.count) 套").font(.system(size: 14))
                            Spacer()
                            Button(AppCopy.text(selected.count == items.count ? "取消全选" : "全选")) {
                                selected = selected.count == items.count ? [] : Set(items.map(\.id))
                            }.font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.primary).frame(minHeight: 44)
                        }.accessibilityIdentifier("mp.transfer.selection")
                    }
                    ForEach(items) { item in itemCard(item) }
                    if exporting && items.isEmpty { AppText("还没有可导出的房源").foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity).padding(.top, 56) }
                }.padding(16)
            }.disabled(busy)
            VStack(spacing: 12) {
                if busy || preparing { AppText(progress).font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                HStack(spacing: 8) {
                    Button(AppCopy.text(busy ? "取消操作" : "取消"), action: cancel).buttonStyle(MPButtonStyle())
                    Button(action: commit) {
                        HStack(spacing: 8) {
                            if busy || preparing { ProgressView() }
                            AppText(exporting ? (retryShare ? "重试发送" : "导出 \(selected.count) 套") : "导入 \(selected.count) 套")
                        }
                    }.buttonStyle(MPButtonStyle(kind: .primary, transferDisabled: true)).disabled(busy || !ready).accessibilityIdentifier("mp.transfer.commit")
                }
            }.padding(16).background(.white).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
        }
    }
    private func itemCard(_ item: MPTransferItem) -> some View {
        MPCard {
            VStack(alignment: .leading, spacing: 12) {
                Button { if !selected.insert(item.id).inserted { selected.remove(item.id) } } label: {
                    HStack(alignment: .top, spacing: 8) {
                        MPCheckbox(selected: selected.contains(item.id)).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(verbatim: item.name).font(.system(size: 17, weight: .semibold))
                                if item.archived { AppText("已删除").font(.system(size: 11)).foregroundStyle(XJTheme.primary).padding(.horizontal, 8).padding(.vertical, 3).background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6)) }
                            }
                            Text(verbatim: item.address.isEmpty ? AppCopy.text("地址未填写") : item.address).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                            AppText("\(item.fields) 条检查记录 · \(item.media) 个影像").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("mp.transfer.select.\(item.id)").accessibilityAddTraits(selected.contains(item.id) ? .isSelected : [])
                if !exporting, let name = item.conflictName, selected.contains(item.id) {
                    XJTheme.line.frame(height: 1)
                    AppText("本机已有「\(name)」，请选择处理方式").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.vertical, 6)
                    HStack(spacing: 8) {
                        mode("覆盖", value: .replace, id: item.id)
                        mode("新增副本", value: .copy, id: item.id)
                    }
                }
            }
        }
    }
    private func mode(_ title: String, value: MPConflictMode, id: String) -> some View {
        Button(AppCopy.text(title)) { modes[id] = value }.buttonStyle(MPButtonStyle(kind: modes[id] == value ? .soft : .plain))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(modes[id] == value ? XJTheme.primary : XJTheme.line))
            .accessibilityIdentifier("mp.transfer.mode.\(id).\(value.rawValue)").accessibilityAddTraits(modes[id] == value ? .isSelected : [])
    }
}
