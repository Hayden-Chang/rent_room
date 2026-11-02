import SwiftUI

struct PlacePicker: View {
    @Bindable var search: PlaceSearch
    var readonly = false
    var address = ""
    var emptyText = "搜索地址或点击定位，选择房源位置"
    let choose: (JSONValue) throws -> Void
    var body: some View {
        PlacePickerSurface(query: Binding(get: { search.query }, set: { search.query = $0; search.submit(debounce: true) }),
                           center: search.center, places: search.choices, busy: search.busy,
                           message: search.message, permissionDenied: search.permissionDenied, readonly: readonly, emptyText: emptyText, address: address, attribution: search.attribution,
                           search: { search.submit() }, locate: { search.locate() }, retry: { search.submit() },
                           settings: { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } },
                           moved: search.moved, choose: { place in
            do { try choose(search.selected(place)); search.didSelect(place) } catch { search.message = error.localizedDescription }
        }).onDisappear { search.cancel() }
    }
}

struct HousePlaceField: View {
    let workspace: AppWorkspace, id: String
    @State private var search: PlaceSearch
    init(workspace: AppWorkspace, id: String) {
        self.workspace = workspace; self.id = id
        let store = workspace.store
        _search = State(initialValue: PlaceSearch(store: store, places: workspace.places, location: store.house(id)["location"], validScope: { workspace.store === store }))
    }
    var body: some View {
        PlacePicker(search: search, readonly: workspace.store.house(id)["archived"].bool, address: workspace.store.house(id)["address"].string) { place in
            try search.store.call("place", ["id": .string(id), "value": place])
        }
            .onAppear { if !workspace.store.house(id)["archived"].bool { search.start(address: workspace.store.house(id)["address"].string) } }
            .onChange(of: workspace.store.house(id)["location"]) { _, value in search.synchronizeLocation(value) }
    }
}

struct WorkplacePage: View {
    let workspace: AppWorkspace
    @State private var text: String
    @State private var error = ""
    @State private var search: PlaceSearch
    @FocusState private var editing: Bool
    init(workspace: AppWorkspace) {
        self.workspace = workspace
        let store = workspace.store
        _text = State(initialValue: store.state["settings"]["workplace"].string)
        _search = State(initialValue: PlaceSearch(store: store, places: workspace.places, location: store.state["settings"]["workplaceLocation"], validScope: { workspace.store === store }))
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SaveBanner(workspace: workspace)
                XJCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            AppText("上班地址").font(.system(size: 17, weight: .semibold)).frame(minHeight: 25.5); Spacer()
                            if !text.isEmpty { Button(AppCopy.text("清空地点")) { save(clear: true) }.font(.system(size: 13)).accessibilityIdentifier("workplace.clear") }
                        }
                        TextField(AppCopy.text("手动填写上班地址或地点"), text: $text, prompt: AppText("手动填写上班地址或地点").foregroundStyle(Color(white: 0.5)), axis: .vertical).lineLimit(2...5).font(.system(size: 14))
                            .lineSpacing(7).padding(12)
                            .frame(minHeight: 72, maxHeight: 144, alignment: .topLeading).background(XJTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 12).focused($editing).accessibilityIdentifier("workplace.address")
                            .onChange(of: text) { if text.count > 200 { text = String(text.prefix(200)) }; save() }
                        AppText("填写后自动保存，也可以在下方搜索或选点。").font(.system(size: 12)).foregroundStyle(XJTheme.muted).frame(minHeight: 18).padding(.top, 10)
                        if !error.isEmpty { AppText(error).font(.system(size: 12)).foregroundStyle(XJTheme.danger); Button(AppCopy.text("重试保存")) { save() } }
                    }
                }
                XJCard {
                    PlacePicker(search: search, address: text, emptyText: "搜索地址或点击定位，选择上班位置") { place in
                        try search.store.call("workplacePlace", ["value": place]); text = search.store.state["settings"]["workplace"].string; error = ""
                    }
                }
            }.padding(16)
        }.background(XJTheme.background).miniNavigation(AppCopy.text("上班地点"))
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(AppCopy.text("完成")) { editing = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
            .onAppear { search.start(address: text) }
    }
    private func save(clear: Bool = false) {
        do {
            guard workspace.store === search.store else { throw CoreFailure(message: "账号已变化，请重新打开页面") }
            if clear { try search.store.call("clearWorkplace"); text = ""; search.reset() }
            else {
                try search.store.call("settings", ["property": .string("workplace"), "value": .string(text)]); try search.store.call("save")
                search.synchronizeLocation(search.store.state["settings"]["workplaceLocation"])
            }
            error = ""
        } catch { self.error = error.localizedDescription }
    }
}

struct CommutePage: View {
    let workspace: AppWorkspace, houseID: String, fieldID: String
    @State private var search: CommuteSearch
    @State private var choosingOrigin = false
    @State private var choosingWorkplace = false
    @Environment(\.dismiss) private var dismiss
    init(workspace: AppWorkspace, houseID: String, fieldID: String) {
        self.workspace = workspace; self.houseID = houseID; self.fieldID = fieldID
        let store = workspace.store
        _search = State(initialValue: CommuteSearch(store: store, houseID: houseID, fieldID: fieldID, key: workspace.mapKey, validScope: { workspace.store === store }))
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        CommuteEndpointRow(origin: true, address: search.endpoints["origin"]["address"].string, hasPoint: search.nativePoint(search.endpoints["origin"]["location"]) != nil) { choosingOrigin = true }
                        XJTheme.line.frame(height: 1).padding(.leading, 38)
                        CommuteEndpointRow(origin: false, address: search.endpoints["destination"]["address"].string, hasPoint: search.nativePoint(search.endpoints["destination"]["location"]) != nil) { choosingWorkplace = true }
                    }.padding(.horizontal, 16).padding(.vertical, 4).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                    CommuteRouteMap(origin: search.nativePoint(search.endpoints["origin"]["location"]), destination: search.nativePoint(search.endpoints["destination"]["location"]), paths: search.chosen?.paths ?? [])
                    HStack { Spacer(); Button(AppCopy.text(search.busy ? "查询中…" : "重新查询")) { search.query() }.font(.system(size: 13)).disabled(search.busy) }
                    if search.busy { XJCard { AppText("正在查询房源到上班地点的路线…").font(.system(size: 13)).foregroundStyle(XJTheme.muted) } }
                    if !search.message.isEmpty { XJCard { AppText(search.message).font(.system(size: 13)).foregroundStyle(XJTheme.muted).accessibilityIdentifier("route.message") } }
                    ForEach(search.routes) { route in CommuteRouteCard(route: route, selected: search.selectedID == route.id) { search.selectedID = route.id } }
                }.padding(16)
            }.background(XJTheme.background)
            CommuteRouteFooter(minutes: search.chosen?.minutes, busy: search.busy, cancel: { search.cancel(); dismiss() }, confirm: {
                do { try search.confirm(); dismiss() } catch { search.message = error.localizedDescription }
            })
        }.miniNavigation(AppCopy.text(fieldID == UtilityField.driving ? "驾车通勤" : "公共交通通勤"))
            .onAppear { search.query() }.onDisappear { search.cancel() }
            .navigationDestination(isPresented: $choosingOrigin) {
                ScrollView { XJCard { HousePlaceField(workspace: workspace, id: houseID) }.padding(16) }.background(XJTheme.background).navigationTitle(AppCopy.text("选择房源位置"))
            }
            .navigationDestination(isPresented: $choosingWorkplace) { WorkplacePage(workspace: workspace) }
    }
}
