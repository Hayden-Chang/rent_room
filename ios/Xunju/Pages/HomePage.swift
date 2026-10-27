import SwiftUI

struct HomePage: View {
    let workspace: AppWorkspace
    @State private var adding = false
    @State private var rename: HouseSummary?
    @State private var path: [String] = []
    @State private var newHouseID: String?
    @State private var capacity = false
    @State private var continueCreate = false
    @State private var capacityAfterName = false
    @State private var feedback = false
    @State private var homeMessage = ""
    @State private var thankYou = false
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                if workspace.store.activeHouses.isEmpty {
                    if !homeMessage.isEmpty {
                        VStack(spacing: 0) {
                            Text("把看过的房子记下来").font(.system(size: 24, weight: .bold)).foregroundStyle(Color(red: 38/255, green: 48/255, blue: 71/255)).frame(height: 33.6).padding(.top, 8).padding(.bottom, 28)
                            XiaodaMessage(text: homeMessage, pose: "greet", compact: false, hero: true) { EmptyView() }
                            Button("新建房源", action: add).buttonStyle(SetupButtonStyle()).padding(.top, 28).accessibilityIdentifier("home.first")
                        }.padding(.horizontal, 4).padding(.top, 24).padding(.bottom, 20)
                    } else { EmptyHouseState(add: add) }
                }
                else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                        ForEach(workspace.store.activeHouses) { house in
                            HouseCard(house: house.card, cover: houseCover(house, store: workspace.store)) { path.append(house.id) }
                                .accessibilityIdentifier("house.\(house.name)")
                                .contextMenu {
                                    Button("重命名") { rename = house }
                                    Button("归档") { workspace.perform { try workspace.store.archive(house.id, archived: true) } }
                                    NavigationLink("导出 ZIP") { BackupPage(workspace: workspace, initialIDs: [house.id]) }
                                }
                        }
                    }
                }
                if !workspace.store.activeHouses.isEmpty && !homeMessage.isEmpty {
                    XiaodaMessage(text: homeMessage, pose: thankYou ? "success" : "point-down-right") {
                        if !thankYou {
                            HStack {
                                Button("再等等") { workspace.perform { try workspace.store.call("waitSecondHouse") }; refreshGuide() }
                                Button("去添加", action: add).buttonStyle(XJButtonStyle(primary: true))
                            }
                        }
                    }
                }
            }.padding(16)
        }.miniNavigation("我的房源", showsBack: false)
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
                NavigationStack { NewHouseSurface(name: workspace.store.state["xiaoda"]["intent"]["name"].string.isEmpty ? "第\(workspace.store.activeHouses.count + 1)套" : workspace.store.state["xiaoda"]["intent"]["name"].string) { value in
                    if workspace.store.capacity.remaining == 0 {
                        try workspace.store.call("beginHouseAction", ["value": .string("create"), "name": .string(value)])
                        capacityAfterName = true; return
                    }
                    let id = try workspace.store.add(value); newHouseID = id; path = [id]
                } }
            }
            .sheet(item: $rename) { house in
                TextPrompt(title: "重命名", placeholder: "填写房源名称", text: house.name) { name in
                    try workspace.store.call("rename", ["id": .string(house.id), "value": .string(name)])
                }
            }
            .fullScreenCover(isPresented: $capacity, onDismiss: {
                if continueCreate { continueCreate = false; adding = true }
                else { workspace.perform { try workspace.store.call("cancelHouseAction") } }
            }) {
                NavigationStack { CapacityPage(workspace: workspace, continued: { result in continueCreate = result["kind"].string == "create" }) }
            }
            .fullScreenCover(isPresented: $feedback) {
                FeedbackPage(workspace: workspace) { thankYou = true; homeMessage = "收到啦，谢谢你的反馈！" }.presentationBackground(.clear)
            }
            .onAppear(perform: refreshGuide)
            .onChange(of: workspace.store.state["xiaoda"]["feedback"]) { _, _ in if path.isEmpty { refreshGuide() } }
            .task(id: thankYou) {
                guard thankYou else { return }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                thankYou = false; refreshGuide()
            }
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
            feedback = value["feedback"].bool
            if !thankYou { homeMessage = value["message"].string }
        }
    }
}

struct ArchivePage: View {
    let workspace: AppWorkspace
    @State private var openedHouse: String?
    @State private var deleting: HouseSummary?
    @State private var capacity = false
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SaveBanner(workspace: workspace)
                if workspace.store.archivedHouses.isEmpty {
                    Text("还没有归档房源").foregroundStyle(XJTheme.muted).padding(.top, 56)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                    ForEach(workspace.store.archivedHouses) { house in
                        MPHouseCard(item: MPHouseItem(id: house.id, card: house.card, cover: houseCover(house, store: workspace.store)), archived: true) { openedHouse = house.id }
                            .accessibilityIdentifier("archive.open.\(house.name)")
                            .contextMenu {
                                Button("还原房源") { workspace.perform {
                                    let info = try workspace.store.call("beginHouseAction", ["id": .string(house.id), "value": .string("restore")])
                                    if info["remaining"].int > 0 { try workspace.store.call("finishHouseAction") } else { capacity = true }
                                } }.accessibilityIdentifier("archive.restore.\(house.name)")
                                Button("彻底删除", role: .destructive) { deleting = house }
                            }
                    }
                }
                if !workspace.store.archivedHouses.isEmpty {
                    Text("长按房源可还原或删除").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(16)
        }.background(XJTheme.background).miniNavigation("归档房源")
            .navigationDestination(item: $openedHouse) { id in HouseDetailPage(workspace: workspace, id: id) }
            .fullScreenCover(isPresented: $capacity) { NavigationStack { CapacityPage(workspace: workspace, continued: { _ in }) } }
            .alert("永久删除房源？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("取消", role: .cancel) { deleting = nil }
                Button("永久删除", role: .destructive) {
                    if let house = deleting { workspace.perform { try workspace.store.call("remove", ["id": .string(house.id)]) } }
                    deleting = nil
                }
            } message: { Text("删除后无法还原，请先导出 ZIP 备份。") }
    }
}
