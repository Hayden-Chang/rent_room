import SwiftUI

struct HomePage: View {
    let workspace: AppWorkspace
    @State private var adding = false
    @State private var rename: HouseSummary?
    @State private var path: [String] = []
    @State private var newHouseID: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                if workspace.store.activeHouses.isEmpty { EmptyHouseState { adding = true } }
                else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
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
            }.padding(16)
        }.navigationTitle("寻居 · 看房手记").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { XJIcon(name: "plus") }
                        .accessibilityLabel("添加房源").accessibilityIdentifier("home.add")
                }
            }
            .navigationDestination(isPresented: Binding(get: { !path.isEmpty }, set: { if !$0 { path = []; newHouseID = nil } })) {
                if let id = path.last { HouseDetailPage(workspace: workspace, id: id, newHouse: newHouseID == id) }
            }
            .sheet(isPresented: $adding) {
                TextPrompt(title: "添加房源", placeholder: "填写房源名称", text: "") { value in
                    let id = try workspace.store.add(value); newHouseID = id; path = [id]
                }
            }
            .sheet(item: $rename) { house in
                TextPrompt(title: "重命名", placeholder: "填写房源名称", text: house.name) { name in
                    try workspace.store.call("rename", ["id": .string(house.id), "value": .string(name)])
                }
            }
    }
}

struct ArchivePage: View {
    let workspace: AppWorkspace
    @State private var deleting: HouseSummary?
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                if workspace.store.archivedHouses.isEmpty {
                    Text("还没有归档房源").foregroundStyle(XJTheme.muted).padding(.top, 56)
                }
                ForEach(workspace.store.archivedHouses) { house in
                    XJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink { HouseDetailPage(workspace: workspace, id: house.id) } label: {
                                HStack { Text(house.name).font(.system(size: 16, weight: .semibold)); Spacer(); Text("只读查看 ›").font(.system(size: 13)) }
                            }.accessibilityIdentifier("archive.open.\(house.name)")
                            Text("\(house.stats.done) / \(house.stats.total) 项 · \(house.stats.issues) 个问题")
                                .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                            HStack {
                                Button("还原") { workspace.perform { try workspace.store.archive(house.id, archived: false) } }
                                    .buttonStyle(XJButtonStyle(primary: false)).accessibilityIdentifier("archive.restore.\(house.name)")
                                Button("永久删除", role: .destructive) { deleting = house }.buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }.padding(16)
        }.background(XJTheme.background).navigationTitle("归档房源").navigationBarTitleDisplayMode(.inline)
            .alert("永久删除房源？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("取消", role: .cancel) { deleting = nil }
                Button("永久删除", role: .destructive) {
                    if let house = deleting { workspace.perform { try workspace.store.call("remove", ["id": .string(house.id)]) } }
                    deleting = nil
                }
            } message: { Text("删除后无法还原，请先导出 ZIP 备份。") }
    }
}
