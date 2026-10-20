import SwiftUI

struct MPHouseItem: Identifiable {
    let id: String
    var card: HouseCardContent
    var cover: UIImage? = nil
    var archived = false
}

struct MPHomeSurface: View {
    let houses: [MPHouseItem]
    let add: () -> Void, open: (String) -> Void, manage: (String) -> Void
    var body: some View {
        ScrollView {
            if houses.isEmpty { EmptyHouseState(add: add).padding(.horizontal, 16) }
            else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                    ForEach(houses) { house in
                        MPHouseCard(item: house) { open(house.id) }
                            .onLongPressGesture { manage(house.id) }.accessibilityIdentifier("mp.house.\(house.id)")
                    }
                }.padding(16).padding(.bottom, 68)
            }
        }.overlay(alignment: .bottomTrailing) {
            if !houses.isEmpty { MPFloatingButton(icon: "plus", label: "添加房源", action: add).padding(16).accessibilityIdentifier("mp.home.add") }
        }
    }
}

struct MPArchiveSurface: View {
    let houses: [MPHouseItem]
    let open: (String) -> Void, manage: (String) -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if houses.isEmpty { Text("还没有归档房源").font(.system(size: 14)).foregroundStyle(XJTheme.muted).padding(.top, 56) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                    ForEach(houses) { house in
                        MPHouseCard(item: house, archived: true) { open(house.id) }
                            .onLongPressGesture { manage(house.id) }.accessibilityIdentifier("mp.archive.\(house.id)")
                    }
                }
                if !houses.isEmpty { Text("长按房源可还原或删除").font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(.vertical, 10) }
            }.padding(16)
        }
    }
}

struct MPHouseCard: View {
    let item: MPHouseItem
    var archived = false
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    XJTheme.soft
                    if let image = item.cover { Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped() }
                    else { XJIcon(name: "home-selected", size: 46).opacity(0.45).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    Text(archived ? "已归档" : item.card.decision.isEmpty ? "待检查" : item.card.decision)
                        .font(.system(size: 11)).foregroundStyle(XJTheme.primary).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6)).padding(10)
                }.frame(height: 142).clipped()
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.card.name).font(.system(size: 14, weight: .semibold)).lineLimit(1).frame(height: 20)
                    Text(item.card.rent.isEmpty ? "租金待填写" : "¥ \(item.card.rent) / 月").font(.system(size: 17, weight: .semibold)).foregroundStyle(XJTheme.primary).frame(height: 24).padding(.vertical, 8)
                    Text("\(item.card.address.isEmpty ? "地址待填写" : item.card.address) · \(item.card.area)m²").font(.system(size: 11)).foregroundStyle(XJTheme.muted).lineLimit(1).frame(height: 16).padding(.bottom, 10)
                    if archived { Text("\(item.card.issues) 个问题").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                    else if item.card.issues > 0 {
                        Text("\(item.card.issues) 个问题").font(.system(size: 11)).foregroundStyle(XJTheme.danger).padding(.horizontal, 8).padding(.vertical, 3).background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 6))
                    } else { Text("检查 \(item.card.done) / \(item.card.total)").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                    Spacer(minLength: 0)
                }.padding(12).frame(height: 144).frame(maxWidth: .infinity, alignment: .leading)
            }.foregroundStyle(XJTheme.ink).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct MPActionMenu: View {
    let title: String
    let actions: [(String, Bool, () -> Void)]
    let close: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            XJTheme.ink.opacity(0.38).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    if !title.isEmpty { Text(title).font(.system(size: 13)).foregroundStyle(XJTheme.muted).padding(16) }
                    ForEach(actions.indices, id: \.self) { index in
                        Button(action: actions[index].2) { Text(actions[index].0).font(.system(size: 16))
                            .foregroundStyle(actions[index].1 ? XJTheme.danger : XJTheme.ink).frame(maxWidth: .infinity, minHeight: 54) }
                            .buttonStyle(.plain).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
                    }
                }.background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                Button("取消", action: close).font(.system(size: 16)).frame(maxWidth: .infinity, minHeight: 54).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }.padding(8)
        }
    }
}

struct MPComparisonSelection: View {
    let houses: [MPHouseItem]
    @Binding var selected: Set<String>
    let compare: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    if houses.count < 2 { Text("选择 2 至 3 套房源进行对比").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                        ForEach(houses) { house in
                            Button { if selected.contains(house.id) { selected.remove(house.id) } else if selected.count < 3 { selected.insert(house.id) } } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    ZStack(alignment: .bottomLeading) {
                                        XJTheme.soft
                                        if let image = house.cover { Image(uiImage: image).resizable().scaledToFill() }
                                        else { XJIcon(name: "home-selected", size: 46).opacity(0.45).frame(maxWidth: .infinity, maxHeight: .infinity) }
                                        Text(selected.contains(house.id) ? "✓" : "").font(.system(size: 18)).foregroundStyle(.white)
                                            .frame(width: 28, height: 28).background(selected.contains(house.id) ? XJTheme.primary : .white)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))
                                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected.contains(house.id) ? XJTheme.primary : Color(red: 196/255, green: 202/255, blue: 213/255)))
                                            .frame(width: 44, height: 44).padding(.leading, 4).padding(.bottom, 2)
                                    }.frame(height: 142).clipped()
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(house.card.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                        Text(house.card.rent.isEmpty ? "租金待填写" : "¥ \(house.card.rent) / 月").font(.system(size: 17, weight: .semibold)).foregroundStyle(XJTheme.primary)
                                        Text("\(house.card.area)m² · \(house.card.decision.isEmpty ? "待检查" : house.card.decision)").font(.system(size: 11)).foregroundStyle(XJTheme.muted)
                                        Spacer(minLength: 0)
                                    }.padding(.horizontal, 11).padding(.vertical, 12).frame(height: 126).frame(maxWidth: .infinity, alignment: .leading)
                                }.background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected.contains(house.id) ? XJTheme.primary : XJTheme.line))
                            }.buttonStyle(.plain).accessibilityIdentifier("mp.compare.\(house.id)").accessibilityAddTraits(selected.contains(house.id) ? .isSelected : [])
                        }
                    }
                }.padding(16)
            }
            Button(selected.count >= 2 ? "对比这 \(selected.count) 套房源" : selected.count == 1 ? "再选 1 套房源" : "选择 2–3 套房源对比", action: compare)
                .font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(selected.count >= 2 ? .white : Color(red: 141/255, green: 149/255, blue: 163/255))
                .background(selected.count >= 2 ? XJTheme.primary : Color(red: 231/255, green: 233/255, blue: 239/255))
                .clipShape(RoundedRectangle(cornerRadius: 12)).disabled(selected.count < 2).buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 22).accessibilityIdentifier("mp.compare.start")
        }
    }
}
