#if DEBUG
import SwiftUI

// Disposable, explicit component-review fixtures. No records, location request,
// Tianditu query, speed download, authentication or purchase happens here.
struct UtilityReviewHost: View {
    let surface: ReviewSurface
    var body: some View {
        switch surface {
        case .place: PlaceReviewHost()
        case .routes: RouteReviewHost()
        case .speed: SpeedReviewHost()
        case .coach: CoachReviewHost()
        case .speedConsent: SpeedConsentReviewHost()
        case .measurements: MeasurementReviewHost()
        default: EmptyView()
        }
    }
}

private enum UtilityFixtures {
    static let origin = GeographicPoint(latitude: 31.2304, longitude: 121.4737)
    static let destination = GeographicPoint(latitude: 31.2404, longitude: 121.4837)
    static let places = [PlaceChoice(id: "one", name: "阳光小区", address: "上海市朝阳路18号", distance: "距中心120米", point: origin),
                         PlaceChoice(id: "two", name: "新城公寓", address: "上海市新城路8号", distance: "距中心350米", point: destination)]
    static let routes = [CommuteRouteChoice(id: "one", title: "步行 → 地铁2号线", minutes: 24, distance: "7.2公里", walk: "850米", transfers: 0, transit: true, paths: [[origin, GeographicPoint(latitude: 31.2354, longitude: 121.4737), destination]]),
                         CommuteRouteChoice(id: "two", title: "公交20路 → 地铁2号线", minutes: 32, distance: "8.1公里", walk: "420米", transfers: 1, transit: true, paths: [[origin, GeographicPoint(latitude: 31.2304, longitude: 121.4837), destination]])]
}

private struct PlaceReviewHost: View {
    @State private var query = ""
    @State private var message = ""
    @State private var denied = false
    @State private var event = ""
    @State private var center = UtilityFixtures.origin
    @State private var readonly = false
    @State private var address = ""
    @State private var viewport = ""
    @State private var cameraDistance = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TextField("手动填写地址", text: $address).textFieldStyle(.roundedBorder)
                        .submitLabel(.done).accessibilityIdentifier("review.placeAddress")
                    XJCard {
                        PlacePickerSurface(query: $query, center: center, places: UtilityFixtures.places, message: message, permissionDenied: denied, readonly: readonly,
                                           address: address,
                                           reviewCameraChanged: { cameraDistance = String(format: "%.0f", $0) },
                                           search: { message = "" }, locate: { denied = true; message = "定位权限未开启，请在设置中允许访问位置" },
                                           retry: { message = "" }, settings: { event = "已触发打开系统设置" }, moved: { point in
                            viewport = String(format: "%.4f,%.4f", point.latitude, point.longitude)
                        }, choose: { place in
                            center = place.point; event = "已选择：\(place.name)"; query = ""
                        })
                    }
                    if !event.isEmpty { Text(event).font(.system(size: 13)).accessibilityIdentifier("review.placeEvent") }
                    Text(viewport).font(.system(size: 10)).accessibilityIdentifier("review.placeViewport")
                    Text(cameraDistance).font(.system(size: 10)).accessibilityIdentifier("review.placeCameraDistance")
                }.padding(16)
            }.background(XJTheme.background).navigationTitle("地点组件").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(readonly ? "可编辑" : "只读") { readonly.toggle() }.accessibilityIdentifier("review.placeReadonly") } }
        }.tint(XJTheme.primary)
    }
}

private struct RouteReviewHost: View {
    @State private var selected = "one"
    @State private var event = ""
    private var chosen: CommuteRouteChoice { UtilityFixtures.routes.first { $0.id == selected }! }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 0) {
                            CommuteEndpointRow(origin: true, address: "朝阳路18号 阳光小区", hasPoint: true) { event = "已触发更改房源位置" }
                            XJTheme.line.frame(height: 1).padding(.leading, 38)
                            CommuteEndpointRow(origin: false, address: "新城路8号 办公楼", hasPoint: true) { event = "已触发更改上班地点" }
                        }.padding(.horizontal, 16).padding(.vertical, 4).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                        CommuteRouteMap(origin: UtilityFixtures.origin, destination: UtilityFixtures.destination, paths: chosen.paths)
                        HStack { Spacer(); Button("重新查询") { event = "已触发重新查询" }.font(.system(size: 13)) }
                        ForEach(UtilityFixtures.routes) { route in
                            CommuteRouteCard(route: route, selected: selected == route.id) { selected = route.id }
                        }
                        if !event.isEmpty { Text(event).font(.system(size: 12)).accessibilityIdentifier("review.routeEvent") }
                    }.padding(16)
                }.background(XJTheme.background)
                CommuteRouteFooter(minutes: chosen.minutes, busy: false, cancel: { event = "已取消，保留原通勤时间" }, confirm: { event = "已确认：\(chosen.minutes)分钟" })
            }.navigationTitle("公共交通通勤").navigationBarTitleDisplayMode(.inline)
        }.tint(XJTheme.primary)
    }
}

private struct SpeedReviewHost: View {
    @State private var state: SpeedDisplayState = .testing
    @State private var reading: SpeedReading? = SpeedReading(bytes: 8_388_608, elapsed: 3200, mbps: 20.97, progress: 40)
    @State private var event = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SpeedStatusCard(state: state, reading: reading,
                                    cancel: { state = .failed("测速已取消"); event = "取消后保留原答案" },
                                    retry: { state = .testing; event = "已重新测速" },
                                    save: { state = .done; event = "已触发重试保存" })
                    if !event.isEmpty { Text(event).font(.system(size: 12)).accessibilityIdentifier("review.speedEvent") }
                }.padding(.horizontal, 16).padding(.top, 24)
            }.background(XJTheme.background).navigationTitle("网速测试").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("评审状态") {
                            Button("有效结果保存失败") { reading = SpeedReading(bytes: 64 * 1024 * 1024, elapsed: 5120, mbps: 104.86, progress: 100); state = .saveError("结果未能保存，请重试；原答案保持不变") }
                            Button("网络失败") { state = .failed("网络连接失败或超时，请稍后重试") }
                        }
                    }
                }
        }.tint(XJTheme.primary)
    }
}

private struct CoachReviewHost: View {
    @State private var step = 1
    @State private var hide = false
    @State private var finished = false
    @State private var selection = ""
    private let steps = [CoachStep(title: "房源信息", body: "记录名称、地址、租金等基本资料。\n「全部」会显示所有阶段的检查项。"),
                         CoachStep(title: "现场检查", body: "到房子里逐项确认采光、家电、\n网络等实际情况。"),
                         CoachStep(title: "询问与签约", body: "选好房源后，再确认合同、费用、\n交接等需要向房东询问的事项。"),
                         CoachStep(title: "左滑检查项", body: "向左滑动一条检查项，即可\n标记问题、写备注或添加影像。")]
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(Array(["全部", "房源信息", "现场检查", "询问签约"].enumerated()), id: \.offset) { index, text in
                        Text(text).font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 40).background(.white).clipShape(Capsule())
                            .anchorPreference(key: CoachAnchors.self, value: .bounds) { index == 0 ? [:] : [index: $0] }
                    }
                }
                XJCard {
                    InspectionChoiceRow(title: "出风正常", options: ["正常", "有问题"], value: $selection, flagged: .constant(false), note: {}, capture: {})
                        .anchorPreference(key: CoachAnchors.self, value: .bounds) { [4: $0] }
                }
                if finished { Text(hide ? "引导结束，下次不再自动显示" : "引导结束").accessibilityIdentifier("review.coachEvent") }
                Spacer()
            }.padding(16).background(XJTheme.background).navigationTitle("清单操作引导").navigationBarTitleDisplayMode(.inline)
        }.overlayPreferenceValue(CoachAnchors.self) { anchors in
            if !finished {
                GeometryReader { geometry in
                    CoachOverlay(steps: steps, step: step, target: anchors[step].map { geometry[$0] }, fieldLabel: "出风正常", hideAutomatically: $hide) {
                        if step < 4 { step += 1 } else { finished = true }
                    }
                }
            }
        }.tint(XJTheme.primary)
    }
}
#endif
