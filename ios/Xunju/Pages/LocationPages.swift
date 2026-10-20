import SwiftUI

struct PlacePicker: View {
    @Bindable var search: PlaceSearch
    let choose: (JSONValue) throws -> Void
    var body: some View {
        PlacePickerSurface(query: $search.query, center: search.center, places: search.choices, busy: search.busy,
                           message: search.message, permissionDenied: search.permissionDenied,
                           search: { search.submit() }, locate: { search.locate() }, retry: { search.submit() },
                           settings: { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } },
                           moved: search.moved, choose: { place in
            do { try choose(search.selected(place)); search.didSelect(place) } catch { search.message = error.localizedDescription }
        }).onChange(of: search.query) { search.submit(debounce: true) }
            .onDisappear { search.cancel() }
    }
}

struct HousePlaceField: View {
    let workspace: AppWorkspace, id: String
    @State private var search: PlaceSearch
    init(workspace: AppWorkspace, id: String) {
        self.workspace = workspace; self.id = id
        let store = workspace.store
        _search = State(initialValue: PlaceSearch(store: store, key: workspace.mapKey, location: store.house(id)["location"], validScope: { workspace.store === store }))
    }
    var body: some View {
        PlacePicker(search: search) { place in
            try search.store.call("place", ["id": .string(id), "value": place])
        }.disabled(workspace.store.house(id)["archived"].bool)
            .onAppear { if !workspace.store.house(id)["archived"].bool { search.start(address: workspace.store.house(id)["address"].string) } }
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
        _search = State(initialValue: PlaceSearch(store: store, key: workspace.mapKey, location: store.state["settings"]["workplaceLocation"], validScope: { workspace.store === store }))
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                XJCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("上班地址").font(.system(size: 15, weight: .semibold)); Spacer()
                            if !text.isEmpty { Button("清空地点") { save(clear: true) }.font(.system(size: 13)).accessibilityIdentifier("workplace.clear") }
                        }
                        TextField("手动填写上班地址或地点", text: $text, axis: .vertical).lineLimit(2...5).font(.system(size: 14))
                            .focused($editing).accessibilityIdentifier("workplace.address")
                            .onChange(of: text) { if text.count > 200 { text = String(text.prefix(200)) }; save() }
                        Text("填写后自动保存，也可以在下方搜索或选点。").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(XJTheme.danger); Button("重试保存") { save() } }
                    }
                }
                XJCard {
                    PlacePicker(search: search) { place in
                        try search.store.call("workplacePlace", ["value": place]); text = search.store.state["settings"]["workplace"].string; error = ""
                    }
                }
            }.padding(16)
        }.background(XJTheme.background).navigationTitle("上班地点").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { editing = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
            .onAppear { search.start(address: text) }
    }
    private func save(clear: Bool = false) {
        do {
            guard workspace.store === search.store else { throw CoreFailure(message: "账号已变化，请重新打开页面") }
            if clear { try search.store.call("clearWorkplace"); text = ""; search.cancel() }
            else { try search.store.call("settings", ["property": .string("workplace"), "value": .string(text)]); try search.store.call("save") }
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
                    HStack { Spacer(); Button(search.busy ? "查询中…" : "重新查询") { search.query() }.font(.system(size: 13)).disabled(search.busy) }
                    if search.busy { XJCard { Text("正在查询房源到上班地点的路线…").font(.system(size: 13)).foregroundStyle(XJTheme.muted) } }
                    if !search.message.isEmpty { XJCard { Text(search.message).font(.system(size: 13)).foregroundStyle(XJTheme.muted).accessibilityIdentifier("route.message") } }
                    ForEach(search.routes) { route in CommuteRouteCard(route: route, selected: search.selectedID == route.id) { search.selectedID = route.id } }
                }.padding(16)
            }.background(XJTheme.background)
            CommuteRouteFooter(minutes: search.chosen?.minutes, busy: search.busy, cancel: { search.cancel(); dismiss() }, confirm: {
                do { try search.confirm(); dismiss() } catch { search.message = error.localizedDescription }
            })
        }.navigationTitle(fieldID == UtilityField.driving ? "驾车通勤" : "公共交通通勤").navigationBarTitleDisplayMode(.inline)
            .onAppear { search.query() }.onDisappear { search.cancel() }
            .navigationDestination(isPresented: $choosingOrigin) {
                ScrollView { XJCard { HousePlaceField(workspace: workspace, id: houseID) }.padding(16) }.background(XJTheme.background).navigationTitle("选择房源位置")
            }
            .navigationDestination(isPresented: $choosingWorkplace) { WorkplacePage(workspace: workspace) }
    }
}
