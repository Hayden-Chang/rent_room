import SwiftUI
import MapKit

struct CommuteEndpointRow: View {
    let origin: Bool
    let address: String
    let hasPoint: Bool
    let edit: () -> Void
    var body: some View {
        Button(action: edit) {
            HStack(spacing: 12) {
                Text(origin ? "起" : "终").font(.system(size: 12))
                    .foregroundStyle(origin ? XJTheme.primary : Color(red: 36 / 255, green: 123 / 255, blue: 91 / 255))
                    .frame(width: 26, height: 26).background(origin ? XJTheme.soft : Color(red: 228 / 255, green: 243 / 255, blue: 237 / 255)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(origin ? "房源" : "上班地点").font(.system(size: 11)).foregroundStyle(XJTheme.muted)
                    Text(address.isEmpty ? (origin ? "选择房源位置" : "未设置上班地点") : address).font(.system(size: 14)).foregroundStyle(XJTheme.ink).lineLimit(2)
                    if !address.isEmpty && !hasPoint { Text("请补选地图位置").font(.system(size: 11)).foregroundStyle(XJTheme.danger) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(address.isEmpty && !origin ? "设置 ›" : "更改 ›").font(.system(size: 12)).foregroundStyle(XJTheme.primary)
            }.padding(.vertical, 14).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(origin ? "route.origin" : "route.destination")
    }
}

struct CommuteRouteChoice: Identifiable {
    let id: String, title: String, minutes: Int, distance: String, walk: String
    let transfers: Int
    let transit: Bool
    let paths: [[GeographicPoint]]
}

struct CommuteRouteCard: View {
    let route: CommuteRouteChoice
    let selected: Bool
    let choose: () -> Void
    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    (Text("\(route.minutes)").font(.system(size: 26, weight: .semibold)) + Text(" 分钟").font(.system(size: 13)))
                        .foregroundStyle(XJTheme.ink)
                    Spacer()
                    Image(systemName: selected ? "checkmark" : "circle").font(.system(size: 20)).foregroundStyle(XJTheme.primary)
                }
                Text(route.title).font(.system(size: 14)).foregroundStyle(XJTheme.ink)
                Text(route.distance + (route.transit ? " · 步行 \(route.walk) · " + (route.transfers > 0 ? "换乘 \(route.transfers) 次" : "无需换乘") : ""))
                    .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .background(selected ? Color(red: 244 / 255, green: 244 / 255, blue: 1) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? XJTheme.primary : XJTheme.line))
        }.buttonStyle(.plain).accessibilityIdentifier("route.option.\(route.id)")
            .accessibilityLabel("\(route.title)，预计\(route.minutes)分钟").accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct CommuteRouteMap: View {
    let origin: GeographicPoint?, destination: GeographicPoint?
    let paths: [[GeographicPoint]]
    var body: some View {
        Group {
            if let origin, let destination {
                Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
                    Marker("房源", coordinate: origin.coordinate).tint(XJTheme.primary)
                    Marker("上班地点", coordinate: destination.coordinate).tint(.green)
                    ForEach(paths.indices, id: \.self) { index in
                        MapPolyline(coordinates: paths[index].map(\.coordinate)).stroke(XJTheme.primary, lineWidth: 5)
                    }
                }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            } else {
                Text("选择起终点后，在这里查看通行路线").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
            }
        }.frame(height: 240).background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("route.map")
    }
}

struct CommuteRouteFooter: View {
    let minutes: Int?
    let busy: Bool
    let cancel: () -> Void, confirm: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button("取消", action: cancel).buttonStyle(XJButtonStyle()).frame(maxWidth: .infinity)
                .accessibilityIdentifier("route.cancel")
            Button(minutes.map { "确定并填入 \($0) 分钟" } ?? "确定并填入", action: confirm)
                .buttonStyle(XJButtonStyle(primary: true)).frame(maxWidth: .infinity)
                .disabled(busy || minutes == nil).opacity(busy || minutes == nil ? 0.45 : 1)
                .accessibilityIdentifier("route.confirm")
                .layoutPriority(1)
        }.padding(.horizontal, 20).padding(.vertical, 14).background(.white)
            .overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
    }
}
