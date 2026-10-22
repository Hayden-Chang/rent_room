import SwiftUI
import MapKit

// Native MapKit / Core Location coordinates are WGS84. The canonical bridge
// converts at the stored GCJ02 boundary; views never perform coordinate math.
struct GeographicPoint: Equatable, Sendable {
    let latitude: Double, longitude: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

struct PlaceChoice: Identifiable, Equatable, Sendable {
    let id: String, name: String, address: String, distance: String
    let point: GeographicPoint
}

struct PlacePickerSurface: View {
    @Binding var query: String
    let center: GeographicPoint?
    let places: [PlaceChoice]
    var busy = false
    var message = ""
    var permissionDenied = false
    var readonly = false
    var emptyText = "搜索地址或点击定位，选择房源位置"
    // The owning address field can collapse this surface without moving it.
    var address = ""
    let search: () -> Void
    let locate: () -> Void
    let retry: () -> Void
    let settings: () -> Void
    let moved: (GeographicPoint) -> Void
    let choose: (PlaceChoice) -> Void
    @State private var position: MapCameraPosition = .automatic
    @State private var viewport: MKCoordinateRegion?
    @State private var collapsed = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            if !readonly {
            HStack(spacing: 4) {
                TextField("搜索地址，更快填写", text: Binding(get: { query }, set: { query = $0; collapsed = true }))
                    .font(.system(size: 14)).submitLabel(.search)
                    .focused($searchFocused).onSubmit { searchFocused = false; search() }
                    .onChange(of: query) { if query.count > 200 { query = String(query.prefix(200)) } }
                    .accessibilityLabel("搜索地址").accessibilityIdentifier("place.query")
                if !query.isEmpty {
                    Button { collapsed = true; query = ""; search() } label: { Image(systemName: "xmark").font(.system(size: 14)).frame(width: 32, height: 42) }
                        .accessibilityLabel("清空搜索").accessibilityIdentifier("place.clear")
                }
            }.padding(.horizontal, 12).frame(minHeight: 44)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
            }
            if !readonly && !query.isEmpty && !places.isEmpty {
                results(nearby: false).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
            }
            if !readonly {
                Button {
                    searchFocused = false
                    if collapsed, let viewport { position = .region(viewport) }
                    collapsed.toggle()
                } label: {
                    HStack {
                        Text(collapsed ? "展开地图" : "收起地图")
                        Spacer()
                        Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                    }.font(.system(size: 13)).padding(.horizontal, 12).frame(minHeight: 44)
                        .background(XJTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).foregroundStyle(XJTheme.primary).accessibilityIdentifier("place.mapToggle")
            }
            ZStack(alignment: .topTrailing) {
                if center != nil {
                    Map(position: $position, interactionModes: readonly ? [.zoom] : [.pan, .zoom]) {}
                        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
                        .mapControlVisibility(.hidden)
                        .onMapCameraChange(frequency: .onEnd) { context in
                            guard !collapsed || readonly else { return }
                            viewport = context.region
                            if !readonly { moved(GeographicPoint(latitude: context.region.center.latitude, longitude: context.region.center.longitude)) }
                        }.accessibilityIdentifier("place.map")
                    Text("●").font(.system(size: 22)).foregroundStyle(XJTheme.primary)
                        .frame(width: 24, height: 24).background(.white).clipShape(Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false).accessibilityHidden(true)
                } else {
                    Text(busy ? "正在匹配地址位置" : emptyText).font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                        .multilineTextAlignment(.center).padding(.horizontal, 20).padding(.top, 65)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                if !readonly {
                Button("定位", action: locate).font(.system(size: 13)).foregroundStyle(XJTheme.primary).padding(10).background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                    .padding(12).accessibilityIdentifier("place.locate")
                }
                if !readonly && query.isEmpty && !places.isEmpty {
                    results(nearby: true).frame(height: 128)
                        .accessibilitySortPriority(1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }.frame(height: collapsed && !readonly ? 0 : 300).clipped()
                .allowsHitTesting(!collapsed || readonly).accessibilityHidden(collapsed && !readonly)
                .background(Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if busy && !readonly { Text("正在查找地点…").font(.system(size: 12)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, alignment: .leading) }
            if (!collapsed || readonly) && (center != nil || !places.isEmpty) {
                Text("地点信息来源：系统地图").font(.system(size: 10)).foregroundStyle(XJTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !message.isEmpty && !readonly {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message).font(.system(size: 12)).foregroundStyle(XJTheme.muted).accessibilityIdentifier("place.message")
                    Button(permissionDenied ? "去设置开启" : "重试", action: permissionDenied ? settings : retry)
                        .font(.system(size: 13)).foregroundStyle(XJTheme.primary).padding(.horizontal, 14).frame(minHeight: 36).background(XJTheme.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("place.retry")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(XJTheme.ink).tint(XJTheme.primary)
            .onAppear { recenter() }.onChange(of: center) { recenter() }
            .onChange(of: address) { if !readonly { collapsed = true } }
    }

    private func recenter() {
        if let center {
            let region = MKCoordinateRegion(center: center.coordinate, span: viewport?.span ?? MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
            viewport = region; position = .region(region)
        }
    }

    private func use(_ place: PlaceChoice) {
        searchFocused = false; choose(place); collapsed = true
    }

    private func results(nearby: Bool) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(places) { place in
                    if nearby {
                        resultRow(place) {
                            Button { use(place) } label: {
                                Text("使用")
                                .font(.system(size: 13)).foregroundStyle(XJTheme.primary)
                                .padding(.horizontal, 12).frame(minHeight: 32).background(XJTheme.soft)
                                .clipShape(RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("place.result.\(place.id)")
                        }
                    } else {
                        Button { use(place) } label: {
                            resultRow(place) { Text("选择").font(.system(size: 13)).foregroundStyle(XJTheme.primary).frame(minHeight: 32) }
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("place.result.\(place.id)")
                    }
                }
            }
        }.background(.white)
    }
    private func resultRow<Action: View>(_ place: PlaceChoice, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name).font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.ink)
                Text([place.distance, place.address].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.system(size: 12)).foregroundStyle(XJTheme.muted).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            action()
        }.padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 52)
            .background(.white).overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
    }
}

