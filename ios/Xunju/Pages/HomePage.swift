import SwiftUI

struct HomePage: View {
    let workspace: AppWorkspace
    @State private var adding = false
    @State private var managed: HouseSummary?
    @State private var exportAfterMenu: String?
    @State private var exporting: String?
    @State private var path: [String] = []
    @State private var newHouseID: String?
    @State private var capacity = false
    @State private var continueCreate = false
    @State private var capacityAfterName = false
    @State private var homeMessage = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                if workspace.store.activeHouses.isEmpty {
                    if !homeMessage.isEmpty {
                        VStack(spacing: 0) {
                            AppText("把看过的房子记下来").font(.system(size: 24, weight: .bold)).foregroundStyle(Color(red: 38/255, green: 48/255, blue: 71/255)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(minHeight: 33.6).padding(.top, 8).padding(.bottom, 28)
                            XiaodaMessage(text: homeMessage, pose: "greet", compact: false, hero: true) { EmptyView() }
                            Button(AppCopy.text("新建房源"), action: add).buttonStyle(SetupButtonStyle()).padding(.top, 28).accessibilityIdentifier("home.first")
                        }.padding(.horizontal, 4).padding(.top, 24).padding(.bottom, 20)
                    } else { EmptyHouseState(add: add) }
                }
                else {
                    HouseLongPressHint()
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                        ForEach(workspace.store.activeHouses) { house in
                            HouseCard(house: house.card, cover: houseCover(house, store: workspace.store)) { path.append(house.id) }
                                .accessibilityIdentifier("house.\(house.name)")
                                .modifier(MPPressActions(tap: { path.append(house.id) }, hold: { managed = house }))
                        }
                    }
                }
                if !workspace.store.activeHouses.isEmpty && !homeMessage.isEmpty {
                    XiaodaMessage(text: homeMessage, pose: "point-down-right") {
                        HStack {
                            Button(AppCopy.text("再等等")) { workspace.perform { try workspace.store.call("waitSecondHouse") }; refreshGuide() }
                            Button(AppCopy.text("去添加"), action: add).buttonStyle(XJButtonStyle(primary: true))
                        }
                    }
                }
            }.padding(16)
        }.miniNavigation(AppCopy.text("我的房源"), showsBack: false)
            .overlay(alignment: .bottomTrailing) {
                if !workspace.store.activeHouses.isEmpty {
                    MPFloatingButton(icon: "plus", label: "新建房源", action: add)
                        .padding(16).accessibilityIdentifier("home.add")
                }
            }
            .navigationDestination(isPresented: Binding(get: { !path.isEmpty }, set: { if !$0 {
                closeHouse()
            } })) {
                if let id = path.last { HouseDetailPage(workspace: workspace, id: id, newHouse: newHouseID == id, returnToHouses: closeHouse) }
            }
            .fullScreenCover(isPresented: $adding, onDismiss: {
                if capacityAfterName { capacityAfterName = false; capacity = true }
                else if path.isEmpty { workspace.perform { try workspace.store.call("cancelHouseAction") } }
            }) {
                NavigationStack { NewHouseSurface(name: workspace.store.state["xiaoda"]["intent"]["name"].string.isEmpty ? AppCopy.text("第\(workspace.store.activeHouses.count + 1)套") : workspace.store.state["xiaoda"]["intent"]["name"].string) { value in
                    if workspace.store.capacity.remaining == 0 {
                        try workspace.store.call("beginHouseAction", ["value": .string("create"), "name": .string(value)])
                        capacityAfterName = true; return
                    }
                    let id = try workspace.store.add(value); newHouseID = id; path = [id]
                } }
            }
            .fullScreenCover(item: $managed, onDismiss: {
                exporting = exportAfterMenu; exportAfterMenu = nil
            }) { house in
                HouseActionSheet(workspace: workspace, house: house, close: { managed = nil },
                    export: { exportAfterMenu = house.id; managed = nil })
                    .presentationBackground(.clear)
            }
            .navigationDestination(item: $exporting) { id in BackupPage(workspace: workspace, initialIDs: [id]) }
            .fullScreenCover(isPresented: $capacity, onDismiss: {
                if continueCreate { continueCreate = false; adding = true }
                else { workspace.perform { try workspace.store.call("cancelHouseAction") } }
            }) {
                NavigationStack { CapacityPage(workspace: workspace, continued: { result in continueCreate = result["kind"].string == "create" }) }
            }
            .onAppear(perform: refreshGuide)
            .modifier(AppReviewPrompt(workspace: workspace, ready: path.isEmpty && !adding && managed == nil
                && exporting == nil && !capacity && !capacityAfterName && !continueCreate))
    }
    private func closeHouse() {
        if let id = path.last { workspace.perform { try workspace.store.call("leaveInspection", ["id": .string(id)]) } }
        path = []; newHouseID = nil; refreshGuide()
    }
    private func add() {
        workspace.perform {
            let info = try workspace.store.call("beginHouseAction", ["value": .string("create")])
            if info["remaining"].int > 0 { adding = true } else { capacity = true }
        }
    }
    private func refreshGuide() {
        guard !workspace.store.status.blocked else { return }
        workspace.perform {
            let value = try workspace.store.call("homeGuide")
            homeMessage = value["message"].string
        }
    }
}

struct ArchivePage: View {
    let workspace: AppWorkspace
    @State private var openedHouse: String?
    @State private var managed: HouseSummary?
    @State private var capacityAfterMenu = false
    @State private var capacity = false
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SaveBanner(workspace: workspace)
                if workspace.store.archivedHouses.isEmpty {
                    AppText("还没有归档房源").foregroundStyle(XJTheme.muted).padding(.top, 56)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                    ForEach(workspace.store.archivedHouses) { house in
                        MPHouseCard(item: MPHouseItem(id: house.id, card: house.card, cover: houseCover(house, store: workspace.store)), archived: true) { openedHouse = house.id }
                            .accessibilityIdentifier("archive.open.\(house.name)")
                            .modifier(MPPressActions(tap: { openedHouse = house.id }, hold: { managed = house }))
                    }
                }
                if !workspace.store.archivedHouses.isEmpty {
                    AppText("长按房源可还原或删除").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(16)
        }.background(XJTheme.background).miniNavigation(AppCopy.text("归档房源"))
            .navigationDestination(item: $openedHouse) { id in HouseDetailPage(workspace: workspace, id: id) }
            .fullScreenCover(isPresented: $capacity) { NavigationStack { CapacityPage(workspace: workspace, continued: { _ in }) } }
            .fullScreenCover(item: $managed, onDismiss: {
                if capacityAfterMenu { capacityAfterMenu = false; capacity = true }
            }) { house in
                HouseActionSheet(workspace: workspace, house: house, close: { managed = nil },
                    capacity: { capacityAfterMenu = true; managed = nil })
                    .presentationBackground(.clear)
            }
    }
}

private struct HouseActionSheet: View {
    let workspace: AppWorkspace
    let house: HouseSummary
    let close: () -> Void
    var export: () -> Void = {}
    var capacity: () -> Void = {}
    @State private var mode = "menu"
    @State private var name = ""
    @State private var error = ""
    var body: some View {
        Group {
            switch mode {
            case "rename":
                MPInputDialog(title: "重命名房源", placeholder: "", text: $name, error: error, cancel: close, save: {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { close(); return }
                    perform { try workspace.store.call("rename", ["id": .string(house.id), "value": .string(name)]) }
                })
            case "archive":
                MPConfirmation(title: "归档房源", message: "归档后保留全部记录，可在设置中还原。", confirmTitle: "确认", cancel: close,
                    confirm: { perform { try workspace.store.archive(house.id, archived: true) } })
            case "delete":
                MPConfirmation(title: "彻底删除房源", message: "将删除本机房源记录，已有导出备份不受影响。请确认已保存需要的备份。", confirmTitle: "确认", cancel: close,
                    confirm: { perform { try workspace.store.call("remove", ["id": .string(house.id)]) } })
            default:
                if house.archived {
                    MPActionMenu(title: "", actions: [("还原房源", false, restore), ("彻底删除", false, { mode = "delete" })],
                        identifiers: ["archive.restore." + house.name, "archive.delete." + house.name], close: close)
                } else {
                    MPActionMenu(title: "", actions: [("重命名", false, { mode = "rename" }), ("归档房源", false, { mode = "archive" }), ("导出房源 ZIP", false, export)], close: close)
                }
            }
        }.foregroundStyle(XJTheme.ink)
            .alert(AppCopy.text("操作失败"), isPresented: Binding(get: { !error.isEmpty && mode != "rename" }, set: { if !$0 { error = "" } })) {
                Button(AppCopy.text("知道了")) { error = "" }
            } message: { AppText(error) }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); close() } catch { self.error = error.localizedDescription }
    }
    private func restore() {
        do {
            try workspace.store.call("beginHouseAction", ["id": .string(house.id), "value": .string("restore")])
            try workspace.store.call("finishHouseAction"); close()
        } catch { self.error = error.localizedDescription }
    }
}
