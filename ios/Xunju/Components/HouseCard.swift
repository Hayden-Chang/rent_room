import SwiftUI

struct HouseCardContent {
    let name: String
    let rent: String
    let address: String
    let area: String
    let decision: String
    let done: Int
    let total: Int
    let issues: Int
}

struct HouseCard: View {
    let house: HouseCardContent
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    XJTheme.soft
                    XJIcon(name: "home-selected", size: 46)
                        .opacity(0.45).frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text(house.decision.isEmpty ? "待检查" : house.decision)
                        .font(.system(size: 11)).foregroundStyle(XJTheme.primary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(10)
                }.frame(height: 142)
                VStack(alignment: .leading, spacing: 0) {
                    Text(house.name).font(.system(size: 14, weight: .semibold))
                        .lineLimit(1).frame(height: 20)
                    Text(house.rent.isEmpty ? "租金待填写" : "¥ \(house.rent) / 月")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(XJTheme.primary)
                        .frame(height: 24).padding(.vertical, 8)
                    Text("\(house.address.isEmpty ? "地址待填写" : house.address) · \(house.area)m²")
                        .font(.system(size: 11)).foregroundStyle(XJTheme.muted)
                        .lineLimit(1).frame(height: 16).padding(.bottom, 10)
                    if house.issues > 0 {
                        Text("\(house.issues) 个问题").font(.system(size: 11))
                            .foregroundStyle(XJTheme.danger).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text("检查 \(house.done) / \(house.total)")
                            .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    }
                    Spacer(minLength: 0)
                }.padding(12).frame(height: 144, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.foregroundStyle(XJTheme.ink).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct EmptyHouseState: View {
    var add: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image("empty-art").resizable().scaledToFit().frame(width: 166, height: 152)
            Button("添加房源", action: add).buttonStyle(XJButtonStyle(primary: true))
                .accessibilityIdentifier("house.add")
        }.padding(.horizontal, 24).padding(.top, 56)
    }
}
