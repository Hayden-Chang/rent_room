#if DEBUG
import SwiftUI

enum MPReviewRoute: String, CaseIterable {
    case home, archive, detail, compare, settings, transfer, workplace, commute, capacity, editor, guide, speed
    static func parse(_ args: [String]) -> MPReviewRoute? {
        guard let index = args.firstIndex(of: "--component-review"), args.indices.contains(index + 1),
              args[index + 1].hasPrefix("parity-") else { return nil }
        return Self(rawValue: String(args[index + 1].dropFirst(7)))
    }
    static func state(_ args: [String]) -> String {
        guard let index = args.firstIndex(of: "--parity-state"), args.indices.contains(index + 1) else { return "" }
        return args[index + 1]
    }
}

// Deliberately no AppWorkspace, identity service, Keychain or purchase client.
// All mutations below are disposable presentation fixtures, never house data.
struct MPReviewHost: View {
    @State private var route: MPReviewRoute
    let state: String
    @State private var mainTab = "房源"
    @State private var houses = MPReviewFixtures.houses
    @State private var prompt = ""
    @State private var promptText = ""
    @State private var menu = ""
    @State private var confirmation = ""
    @State private var nickname = "小林"
    @State private var onboarding = true
    @State private var selected: Set<String> = []
    @State private var modes: [String: MPConflictMode] = [:]
    @State private var comparing = false
    @State private var differences = false
    @State private var transferBusy = false
    @State private var address = ""
    @State private var placeQuery = ""
    @State private var placeError = ""
    @State private var picking = false
    @State private var routeSelected = "one"
    @State private var activity: CapacityActivity = .idle
    @State private var toast = ""
    init(route: MPReviewRoute, state: String) {
        _route = State(initialValue: route); self.state = state
        _houses = State(initialValue: state == "empty" ? [] : MPReviewFixtures.houses)
        _mainTab = State(initialValue: route == .settings ? "我的" : route == .compare ? "对比" : "房源")
        _selected = State(initialValue: route == .transfer && state != "empty" ? ["one", "two"] : [])
        _activity = State(initialValue: CapacityActivity(rawValue: state) ?? .idle)
    }
    private var rootPage: Bool { [.home, .compare, .settings].contains(route) }
    private var modal: Bool { !prompt.isEmpty || !menu.isEmpty || !confirmation.isEmpty }
    private var title: String {
        switch route {
        case .home: "我的房源"
        case .archive: "归档房源"
        case .detail: "阳光小区"
        case .compare: "房源对比"
        case .settings: "我的"
        case .transfer: state == "export" ? "导出房源" : "导入房源"
        case .workplace: "上班地点"
        case .commute: "公共交通通勤"
        case .capacity: "房源容量"
        case .editor: "新建问题"
        case .guide: "阳光小区"
        case .speed: "网速测试"
        }
    }
    var body: some View {
        ZStack {
            if route == .guide { MPGuideReviewHost() }
            else if route == .editor { MPIssueReviewHost(state: state, close: { route = .detail }) }
            else { MPFrame(title: title, back: rootPage ? nil : { route = .home; mainTab = "房源" }) {
                surface
            } footer: {
                if rootPage { MPTabBar(selection: $mainTab) }
            }.accessibilityHidden(modal).allowsHitTesting(!modal) }
            overlays
            if !toast.isEmpty { MPToast(text: toast) }
        }.tint(XJTheme.primary)
            .onChange(of: mainTab) { route = mainTab == "房源" ? .home : mainTab == "对比" ? .compare : .settings }
            .task(id: toast) {
                guard !toast.isEmpty else { return }
                // Matches transient product feedback; no test-specific extension.
                try? await Task.sleep(for: .milliseconds(1500))
                if !Task.isCancelled { toast = "" }
            }
    }
    @ViewBuilder private var surface: some View {
        switch route {
        case .home:
            MPHomeSurface(houses: houses, add: { prompt = "新建房源"; promptText = "" }, open: { _ in route = .detail }, manage: { menu = $0 })
        case .archive:
            MPArchiveSurface(houses: houses, open: { _ in route = .detail }, manage: { menu = $0 })
        case .detail:
            MPDetailReviewHost(state: state, back: { route = .home })
        case .compare:
            if comparing {
                MPComparisonResults(names: houses.filter { selected.contains($0.id) }.map(\.card.name), rows: MPReviewFixtures.comparison, differences: $differences) { comparing = false }
            } else { MPComparisonSelection(houses: houses, selected: $selected) { comparing = true } }
        case .settings:
            MPSettingsSurface(authenticated: state != "guest", nickname: $nickname, used: 2, archived: 2,
                accountReady: state != "waiting", recoveryBlocked: state == "recovery", onboarding: $onboarding,
                appleRequest: { _ in }, appleCompletion: { _ in },
                avatarAction: { toast = "请选择头像" }, nicknameCommit: {}, capacity: { route = .capacity },
                openWorkplace: { route = .workplace }, archive: { route = .archive }, importFile: { route = .transfer },
                export: { route = .transfer }, permissions: { toast = "前往系统设置管理权限" }, logout: { confirmation = "logout" },
                recover: { toast = "正在尝试恢复本机记录…" })
        case .transfer:
            MPTransferSurface(exporting: state == "export", items: state == "empty" ? [] : MPReviewFixtures.transfers, selected: $selected, modes: $modes,
                fileName: state == "empty" ? "" : "看房搭子房源-2026-10-20.zip", busy: transferBusy, preparing: state == "preparing",
                progress: "正在整理房源与影像…", error: state == "error" ? "文件无法读取，请重新选择 ZIP" : "",
                choose: { toast = "请选择 ZIP 文件" }, cancel: { route = .home }, commit: { transferBusy = true })
        case .workplace:
            MPWorkplaceSurface(address: $address, clear: { address = "" }, retry: { placeError = "" }) { placePicker(workplace: true) }
        case .commute:
            MPCommuteSurface(originAddress: "朝阳路18号 阳光小区", destinationAddress: "新城路8号 办公楼",
                origin: nil, destination: nil, routes: state == "empty" ? [] : MPReviewFixtures.routes, selected: $routeSelected, picking: $picking,
                workplace: { route = .workplace }, retry: {}, cancel: { route = .detail }, confirm: { route = .detail }) { placePicker() }
        case .capacity:
            MPCapacitySurface(used: state == "over" ? 12 : 2, limit: 2, authenticated: state != "guest", price: state == "unavailable" ? nil : "¥1.99",
                activity: activity, error: state == "unavailable" ? "房源包暂未开放，请稍后再试" : state == "error" ? "购买记录暂时无法确认，请重试" : "",
                purchase: { if state == "guest" { route = .settings } else { activity = .purchasing } }, restore: { activity = .restoring })
        case .editor:
            MPIssueReviewHost(state: state, close: { route = .detail })
        case .guide: EmptyView()
        case .speed:
            ScrollView {
                SpeedStatusCard(state: state == "done" ? .done : state == "error" ? .saveError("结果未能保存，请重试；原答案保持不变") : .testing,
                    reading: SpeedReading(bytes: 8_388_608, elapsed: 3200, mbps: 20.97, progress: state == "done" ? 100 : 40),
                    doneMessage: "测速结果已回填", cancel: { route = .detail }, retry: {}, save: { toast = "网速已回填" })
                    .padding(.horizontal, 16).padding(.top, 24)
            }
        }
    }
    private func placePicker(workplace: Bool = false) -> some View {
        PlacePickerSurface(query: $placeQuery, center: nil, places: placeQuery.isEmpty ? [] : MPReviewFixtures.places,
            message: placeError, permissionDenied: !placeError.isEmpty,
            emptyText: workplace ? "搜索地址或点击定位，选择上班位置" : "搜索地址或点击定位，选择房源位置",
            search: {}, locate: { placeError = "定位权限未开启，请在设置中允许访问位置" }, retry: { placeError = "" },
            settings: { toast = "请在系统设置中允许访问位置" }, moved: { _ in },
            choose: { address = $0.address; placeQuery = ""; picking = false })
    }
    @ViewBuilder private var overlays: some View {
        if !prompt.isEmpty {
            MPInputDialog(title: prompt, placeholder: "填写房源名称或地址", text: $promptText, cancel: { prompt = "" }, save: {
                let name = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    let old = MPReviewFixtures.houses[0].card
                    houses.append(MPHouseItem(id: UUID().uuidString, card: HouseCardContent(name: name, rent: "", address: "", area: "—", decision: "", done: 0, total: old.total, issues: 0)))
                    prompt = ""
                }
            })
        }
        if !menu.isEmpty {
            MPActionMenu(title: "", actions: route == .archive ?
                [("还原房源", false, { confirmation = "restore"; menu = "" }), ("永久删除", true, { confirmation = "delete"; menu = "" })] :
                [("重命名", false, { prompt = "重命名"; promptText = "阳光小区"; menu = "" }),
                 ("归档房源", false, { confirmation = "archive"; menu = "" }),
                 ("导出房源 ZIP", false, { route = .transfer; menu = "" })], close: { menu = "" })
        }
        if !confirmation.isEmpty {
            MPConfirmation(title: confirmation == "archive" ? "归档房源" : confirmation == "logout" ? "退出登录" : confirmation == "delete" ? "永久删除房源" : "还原房源",
                message: confirmation == "archive" ? "归档后保留全部记录，可在设置中还原" : confirmation == "delete" ? "删除后无法恢复，请确认是否继续" : "确定继续吗？",
                confirmTitle: "确定", destructive: confirmation == "delete", cancel: { confirmation = "" }, confirm: { confirmation = ""; toast = "操作已完成" })
        }
    }
}

private enum MPReviewError: LocalizedError {
    case serviceUnavailable
    var errorDescription: String? { "短信登录服务暂未配置，请稍后重试" }
}

enum MPReviewFixtures {
    static let houses = [
        MPHouseItem(id: "one", card: HouseCardContent(name: "阳光小区", rent: "3200", address: "朝阳路18号", area: "68", decision: "继续比较", done: 86, total: 302, issues: 3)),
        MPHouseItem(id: "two", card: HouseCardContent(name: "新城公寓", rent: "2800", address: "新城路8号", area: "52", decision: "", done: 34, total: 302, issues: 0))
    ]
    static let transfers = [
        MPTransferItem(id: "one", name: "阳光小区", address: "朝阳路18号", fields: 86, media: 4, conflictName: "阳光小区"),
        MPTransferItem(id: "two", name: "新城公寓", address: "新城路8号", fields: 34, media: 2, archived: true)
    ]
    static let comparison = [
        MPComparisonRow(id: "rent", label: "月租金", values: ["3200", "2800"]),
        MPComparisonRow(id: "area", label: "面积", values: ["68", "52"]),
        MPComparisonRow(id: "floor", label: "电梯", values: ["有", "有"]),
        MPComparisonRow(id: "light", label: "采光", values: ["充足", "一般"])
    ]
    static let places = [PlaceChoice(id: "one", name: "新城办公楼", address: "新城路8号", distance: "距中心120米", point: GeographicPoint(latitude: 31.2304, longitude: 121.4737))]
    static let routes = [
        CommuteRouteChoice(id: "one", title: "步行 → 地铁2号线", minutes: 24, distance: "7.2公里", walk: "850米", transfers: 0, transit: true, paths: []),
        CommuteRouteChoice(id: "two", title: "公交20路 → 地铁2号线", minutes: 32, distance: "8.1公里", walk: "420米", transfers: 1, transit: true, paths: [])
    ]
}
#endif
