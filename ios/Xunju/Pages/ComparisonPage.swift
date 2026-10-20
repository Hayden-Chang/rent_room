import SwiftUI

struct ComparisonPage: View {
    let workspace: AppWorkspace
    @State private var selected: [String] = []
    @State private var comparing = false
    @State private var differences = false
    @State private var rows: [JSONValue] = []
    private var houses: [HouseSummary] { workspace.store.activeHouses }
    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(spacing: 16) {
                if comparing {
                    Toggle("隐藏相同属性", isOn: $differences).tint(XJTheme.primary).font(.system(size: 13))
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow {
                            cell("属性", header: true)
                            ForEach(selected, id: \.self) { id in cell(workspace.store.house(id)["name"].string, header: true) }
                        }
                        ForEach(rows, id: \.id) { row in
                            GridRow {
                                cell(row["label"].string)
                                ForEach(Array(row["values"].array.enumerated()), id: \.offset) { _, value in cell(value.string) }
                            }.background(Set(row["values"].array).count > 1 ? XJTheme.soft.opacity(0.4) : .white)
                                .accessibilityElement(children: .contain).accessibilityIdentifier("compare.row.\(row.id)")
                        }
                    }
                    if rows.isEmpty { Text("所选房源没有已显示的差异").foregroundStyle(XJTheme.muted) }
                } else {
                    Text("选择 2 至 3 套房源进行对比").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(houses) { house in
                            HouseCard(house: house.card, cover: houseCover(house, store: workspace.store)) { toggle(house.id) }
                                .overlay(alignment: .topTrailing) {
                                    Text(selected.contains(house.id) ? "✓" : "").font(.system(size: 18, weight: .semibold))
                                        .frame(width: 28, height: 28).foregroundStyle(.white)
                                        .background(selected.contains(house.id) ? XJTheme.primary : .white)
                                        .clipShape(Circle()).overlay(Circle().stroke(XJTheme.line)).padding(10).allowsHitTesting(false)
                                }.overlay(RoundedRectangle(cornerRadius: 16).stroke(selected.contains(house.id) ? XJTheme.primary : .clear, lineWidth: 2))
                                .accessibilityIdentifier("compare.select.\(house.name)")
                        }
                    }
                }
            }.padding(16)
        }
        VStack(spacing: 0) {
                Button(comparing ? "返回选择房源" : selected.count >= 2 ? "对比这 \(selected.count) 套房源" : selected.count == 1 ? "再选 1 套房源" : "选择 2–3 套房源对比") {
                    if comparing { comparing = false }
                    else { refresh(); comparing = true }
                }.buttonStyle(XJButtonStyle(primary: true)).disabled(!comparing && selected.count < 2)
                    .accessibilityIdentifier("compare.start")
            }.padding(16).background(XJTheme.background)
        }.navigationTitle("房源对比").navigationBarTitleDisplayMode(.inline)
            .onChange(of: differences) { _, _ in refresh() }
            .onChange(of: houses.map(\.id)) { _, ids in selected.removeAll { !ids.contains($0) }; if selected.count < 2 { comparing = false } }
            .onChange(of: workspace.store.status.revision) { _, _ in if comparing { refresh() } }
    }
    private func cell(_ value: String, header: Bool = false) -> some View {
        Text(value).font(.system(size: 12, weight: header ? .semibold : .regular)).foregroundStyle(XJTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(8)
            .background(header ? XJTheme.soft : .clear).border(XJTheme.line, width: 0.5)
    }
    private func toggle(_ id: String) {
        if let index = selected.firstIndex(of: id) { selected.remove(at: index) }
        else if selected.count < 3 { selected.append(id) }
        else { workspace.error = "最多选择 3 套房源" }
    }
    private func refresh() {
        guard selected.count >= 2 else { return }
        workspace.perform { rows = try workspace.store.call("compare", ["ids": .array(selected.map(JSONValue.string)), "differences": .bool(differences)]).array }
    }
}
