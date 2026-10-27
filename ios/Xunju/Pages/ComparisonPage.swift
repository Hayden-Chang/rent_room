import SwiftUI

struct ComparisonPage: View {
    let workspace: AppWorkspace
    @State private var selected: [String] = []
    @State private var comparing = false
    @State private var differences = false
    @State private var rows: [JSONValue] = []
    private var houses: [HouseSummary] { workspace.store.activeHouses }
    private var footerTitle: String { comparing ? "返回选择房源" : selected.count >= 2 ? "对比这 \(selected.count) 套房源" : selected.count == 1 ? "再选 1 套房源" : "选择 2–3 套房源对比" }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        if comparing {
                            Toggle("隐藏相同属性", isOn: $differences).toggleStyle(MPSwitchStyle())
                                .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 12).frame(minHeight: 48)
                                .background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 8)
                            table(width: max(0, geometry.size.width - 32))
                            if rows.isEmpty { Text("所选房源没有已显示的差异").foregroundStyle(XJTheme.muted) }
                        } else {
                            if houses.count < 2 { Text("选择 2 至 3 套房源进行对比").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading) }
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                                ForEach(houses) { house in
                                    ComparisonHouseCard(house: house, cover: houseCover(house, store: workspace.store), selected: selected.contains(house.id)) { toggle(house.id) }
                                        .accessibilityIdentifier("compare.select.\(house.name)")
                                }
                            }
                        }
                    }.padding(16)
                }
                Button {
                    if comparing { comparing = false }
                    else { refresh(); comparing = true }
                } label: {
                    Text(footerTitle).font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(!comparing && selected.count < 2 ? Color(red: 141 / 255, green: 149 / 255, blue: 163 / 255) : .white)
                        .background(!comparing && selected.count < 2 ? Color(red: 231 / 255, green: 233 / 255, blue: 239 / 255) : XJTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(ComparisonFooterButtonStyle()).disabled(!comparing && selected.count < 2)
                    .accessibilityIdentifier("compare.start").padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 22)
            }
        }.miniNavigation("房源对比", showsBack: false)
            .onChange(of: differences) { _, _ in refresh() }
            .onChange(of: houses.map(\.id)) { _, ids in selected.removeAll { !ids.contains($0) }; if selected.count < 2 { comparing = false } }
            .onChange(of: workspace.store.status.revision) { _, _ in if comparing { refresh() } }
    }
    private func table(width: CGFloat) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                cell("属性", width: width * 0.26, label: true, header: true)
                ForEach(selected, id: \.self) { id in cell(workspace.store.house(id)["name"].string, width: width * 0.74 / CGFloat(selected.count), header: true) }
            }.background(XJTheme.soft)
            ForEach(rows, id: \.id) { row in
                GridRow {
                    cell(row["label"].string, width: width * 0.26, label: true)
                    ForEach(Array(row["values"].array.enumerated()), id: \.offset) { _, value in
                        cell(value.string, width: width * 0.74 / CGFloat(selected.count))
                    }
                }.background(Set(row["values"].array).count > 1 ? Color(red: 1, green: 245 / 255, blue: 206 / 255) : .white)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("compare.row.\(row.id)")
            }
        }.clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func cell(_ value: String, width: CGFloat, label: Bool = false, header: Bool = false) -> some View {
        Text(value).font(.system(size: label ? 12 : 13, weight: header ? .semibold : .regular))
            .foregroundStyle(label || value == "未填写" ? XJTheme.muted : XJTheme.ink)
            .multilineTextAlignment(label ? .leading : .center).padding(.vertical, 16).padding(.horizontal, label ? 12 : 6)
            .frame(width: width).frame(minHeight: header ? 74 : 56, alignment: label ? .leading : .center)
            .overlay(alignment: .bottom) { Rectangle().fill(XJTheme.line).frame(height: 1) }
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

private struct ComparisonHouseCard: View {
    let house: HouseSummary
    let cover: UIImage?
    let selected: Bool
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    XJTheme.soft
                    if let cover { Image(uiImage: cover).resizable().scaledToFill() }
                    else { XJIcon(name: "home-selected", size: 46).opacity(0.45).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    Text(selected ? "✓" : "").font(.system(size: 18)).foregroundStyle(.white).frame(width: 28, height: 28)
                        .background(selected ? XJTheme.primary : .white).clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? XJTheme.primary : Color(red: 196 / 255, green: 202 / 255, blue: 213 / 255)))
                        .frame(width: 44, height: 44).padding(.leading, 4).padding(.bottom, 2)
                }.frame(height: 142).clipped()
                VStack(alignment: .leading, spacing: 0) {
                    Text(house.name).font(.system(size: 14, weight: .semibold)).lineLimit(1).frame(height: 20)
                    Text(house.rent.isEmpty ? "租金待填写" : "¥ \(house.rent) / 月").font(.system(size: 17, weight: .semibold)).foregroundStyle(XJTheme.primary).frame(height: 24).padding(.vertical, 8)
                    Text("\(house.area)m² · \(house.decision.isEmpty ? "待检查" : house.decision)").font(.system(size: 11, weight: .medium)).foregroundStyle(XJTheme.muted).lineLimit(1)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 11).padding(.vertical, 12).frame(height: 126).frame(maxWidth: .infinity, alignment: .leading)
            }.foregroundStyle(XJTheme.ink).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? XJTheme.primary : XJTheme.line).allowsHitTesting(false))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Disabled colors are explicit in the mini-program; PlainButtonStyle adds a second dimming pass.
private struct ComparisonFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}
