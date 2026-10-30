import SwiftUI

struct MPWorkplaceSurface<Picker: View>: View {
    @Binding var address: String
    var error = ""
    let clear: () -> Void, retry: () -> Void
    @ViewBuilder var picker: Picker
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !error.isEmpty { Button(AppCopy.text(error + " 点击重试"), action: retry).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12).background(XJTheme.dangerBackground) }
                MPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AppText("上班地址").font(.system(size: 17, weight: .semibold))
                            Spacer()
                            if !address.isEmpty { Button(AppCopy.text("清空地点"), action: clear).font(.system(size: 13)).foregroundStyle(XJTheme.primary).frame(minHeight: 32) }
                        }
                        TextField(AppCopy.text("手动填写上班地址或地点"), text: $address, axis: .vertical).lineLimit(2...5)
                            .font(.system(size: 14)).lineSpacing(7).padding(.horizontal, 12).padding(.vertical, 10)
                            .frame(minHeight: 72, maxHeight: 144, alignment: .topLeading).background(XJTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: address) { address = String(address.prefix(200)) }.accessibilityIdentifier("mp.workplace.address")
                        AppText("填写后自动保存，也可以在下方搜索或选点。").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    }
                }
                MPCard { picker }
            }.padding(16)
        }
    }
}

struct MPCommuteEndpoint: View {
    let origin: Bool, address: String, hasPoint: Bool
    let edit: () -> Void
    var body: some View {
        Button(action: edit) {
            HStack(spacing: 12) {
                AppText(origin ? "起" : "终").font(.system(size: 12)).foregroundStyle(origin ? XJTheme.primary : Color(red: 36/255, green: 123/255, blue: 91/255))
                    .frame(width: 26, height: 26).background(origin ? XJTheme.soft : Color(red: 228/255, green: 243/255, blue: 237/255)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    AppText(origin ? "房源" : "上班地点").font(.system(size: 11)).foregroundStyle(XJTheme.muted)
                    Text(verbatim: address.isEmpty ? AppCopy.text(origin ? "选择房源位置" : "未设置上班地点") : address).font(.system(size: 14)).lineLimit(2)
                    if !address.isEmpty && !hasPoint { AppText("请补选地图位置").font(.system(size: 11)).foregroundStyle(XJTheme.danger) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                AppText(origin ? "更改 ›" : address.isEmpty ? "设置 ›" : "修改 ›").font(.system(size: 12)).foregroundStyle(XJTheme.primary)
            }.padding(.vertical, 14).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(origin ? "mp.route.origin" : "mp.route.destination")
    }
}

struct MPCommuteSurface<Picker: View>: View {
    let originAddress: String, destinationAddress: String
    let origin: GeographicPoint?, destination: GeographicPoint?
    let routes: [CommuteRouteChoice]
    @Binding var selected: String
    @Binding var picking: Bool
    var busy = false, message = ""
    let workplace: () -> Void, retry: () -> Void, cancel: () -> Void, confirm: () -> Void
    @ViewBuilder var picker: Picker
    private var chosen: CommuteRouteChoice? { routes.first { $0.id == selected } }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    if picking {
                        MPCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { AppText("选择房源位置").font(.system(size: 17, weight: .semibold)); Spacer(); Button(AppCopy.text("取消")) { picking = false }.font(.system(size: 13)).accessibilityIdentifier("mp.route.picker.cancel") }
                                AppText("选择后更新这套房源的地址").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                                picker
                            }
                        }
                    } else {
                        VStack(spacing: 0) {
                            MPCommuteEndpoint(origin: true, address: originAddress, hasPoint: origin != nil) { picking = true }
                            XJTheme.line.frame(height: 1).padding(.leading, 38)
                            MPCommuteEndpoint(origin: false, address: destinationAddress, hasPoint: destination != nil, edit: workplace)
                        }.padding(.horizontal, 16).padding(.vertical, 4).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                        CommuteRouteMap(origin: origin, destination: destination, paths: chosen?.paths ?? [])
                        HStack { Spacer(); Button(AppCopy.text(busy ? "查询中…" : "重新查询"), action: retry).font(.system(size: 13)).disabled(busy) }.padding(.vertical, 4)
                        if busy || !message.isEmpty { MPCard { AppText(busy ? "正在查询房源到上班地点的路线…" : message).font(.system(size: 13)).foregroundStyle(XJTheme.muted) } }
                        ForEach(routes) { route in
                            Button { selected = route.id } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        (AppText("\(route.minutes)").font(.system(size: 26, weight: .semibold)) + AppText(" 分钟").font(.system(size: 13)))
                                        Spacer(); AppText(selected == route.id ? "✓" : "○").font(.system(size: 20)).foregroundStyle(XJTheme.primary)
                                    }
                                    AppText(route.title).font(.system(size: 14)).padding(.vertical, 2)
                                    AppText(route.distance + (route.transit ? " · 步行 \(route.walk) · " + (route.transfers > 0 ? "换乘 \(route.transfers) 次" : "无需换乘") : "")).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                                    .background(selected == route.id ? Color(red: 244/255, green: 244/255, blue: 1) : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(selected == route.id ? XJTheme.primary : XJTheme.line))
                            }.buttonStyle(.plain).accessibilityIdentifier("mp.route.option.\(route.id)").accessibilityAddTraits(selected == route.id ? .isSelected : [])
                        }
                    }
                }.padding(16)
            }
            if !picking {
                GeometryReader { geometry in
                    let unit = max(0, geometry.size.width - 12) / 3
                    HStack(spacing: 12) {
                        Button(AppCopy.text("取消"), action: cancel).buttonStyle(MPButtonStyle(kind: .soft)).frame(width: unit)
                        Button(AppCopy.text(chosen.map { "确定并填入 \($0.minutes) 分钟" } ?? "确定并填入"), action: confirm)
                            .font(.system(size: 14, weight: .medium)).frame(width: unit * 2, height: 46)
                            .foregroundStyle(busy || chosen == nil ? Color(red: 135/255, green: 146/255, blue: 165/255) : .white)
                            .background(busy || chosen == nil ? Color(red: 220/255, green: 224/255, blue: 233/255) : XJTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8)).buttonStyle(.plain).disabled(busy || chosen == nil).accessibilityIdentifier("mp.route.confirm")
                    }
                }.frame(height: 46).padding(.horizontal, 20).padding(.vertical, 14).background(.white).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
            }
        }
    }
}

struct MPCapacitySurface: View {
    let used: Int, limit: Int, authenticated: Bool, price: String?
    var activity: CapacityActivity = .idle
    var error = ""
    let purchase: () -> Void, restore: () -> Void
    private var enabled: Bool { !activity.busy && activity != .pending && (!authenticated || price != nil) }
    private var title: String {
        if activity == .loading { return "正在加载房源包…" }
        if activity == .purchasing { return "正在确认购买…" }
        if activity == .pending { return "等待购买结果" }
        if !authenticated { return "登录后购买" }
        return price.map { $0 + " 扩容10个" } ?? "房源包暂未开放"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MPCard(padding: 24) {
                    VStack(alignment: .leading, spacing: 0) {
                        AppText("房源容量").font(.system(size: 17, weight: .semibold))
                        (AppText("\(used)").font(.system(size: 38, weight: .semibold)).foregroundStyle(XJTheme.primary) + AppText(" / \(limit) 套").font(.system(size: 16)).foregroundStyle(XJTheme.muted))
                            .padding(.top, 12).padding(.bottom, 4).accessibilityIdentifier("mp.capacity.total")
                    }
                }
                MPCard(padding: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            AppText("房源包").font(.system(size: 17, weight: .semibold)); Spacer()
                            if activity == .loading { ProgressView().accessibilityLabel(AppCopy.text("正在加载价格")) }
                            else { AppText(price ?? "暂不可用").font(.system(size: price == nil ? 14 : 24, weight: .semibold)).foregroundStyle(XJTheme.primary) }
                        }
                        AppText("增加 10 套房源容量").font(.system(size: 16)).padding(.top, 12)
                        if !authenticated { AppText("购买或恢复已购容量需登录，免费记录可继续使用。").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                        Button(action: purchase) {
                            HStack(spacing: 8) { if activity == .purchasing { ProgressView().tint(.white) }; AppText(title) }
                        }.buttonStyle(MPButtonStyle(kind: .primary)).disabled(!enabled).padding(.top, 24).accessibilityIdentifier("mp.capacity.purchase")
                    }
                }
                if activity == .pending { AppText("支付结果仍在确认，请稍后重试。").font(.system(size: 14)).foregroundStyle(XJTheme.primary).padding(12).background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 10)) }
                if !error.isEmpty { AppText(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 10)) }
                Button(action: restore) {
                    HStack(spacing: 8) { if activity == .restoring { ProgressView() }; AppText(activity == .restoring ? "正在恢复容量…" : authenticated ? "恢复已购容量" : "登录并恢复容量") }
                        .font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.plain).foregroundStyle(XJTheme.primary).disabled(activity.busy).opacity(activity.busy ? 0.45 : 1).padding(.top, 12).accessibilityIdentifier("mp.capacity.restore")
            }.padding(16)
        }
    }
}
