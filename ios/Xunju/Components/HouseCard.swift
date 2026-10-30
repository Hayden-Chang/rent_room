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
    var currencyCode = "CNY"
}

struct HouseCard: View {
    let house: HouseCardContent
    var cover: UIImage? = nil
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    XJTheme.soft.overlay {
                        if let cover {
                            GeometryReader { geometry in
                                Image(uiImage: cover).resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            }
                        }
                        else { XJIcon(name: "home-selected", size: 46).opacity(0.45) }
                    }.clipped()
                    AppText(house.decision.isEmpty ? "待检查" : house.decision)
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(XJTheme.primary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(10)
                }.frame(height: 142).clipped()
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: house.name).font(.system(size: 14, weight: .semibold))
                        .lineLimit(1).frame(height: 20)
                    AppText(house.rent.isEmpty ? "租金待填写" : "\(house.currencyCode) \(house.rent) / 月")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(XJTheme.primary)
                        .frame(height: 24).padding(.vertical, 8)
                    Text(verbatim: "\(house.address.isEmpty ? AppCopy.text("地址待填写") : house.address) · \(house.area)m²")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(XJTheme.muted)
                        .lineLimit(1).frame(height: 16).padding(.bottom, 10)
                    if house.issues > 0 {
                        AppText("\(house.issues) 个问题").font(.system(size: 11, weight: .medium))
                            .foregroundStyle(XJTheme.danger).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        AppText("检查 \(house.done) / \(house.total)")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted)
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
        VStack(spacing: 36) {
            Image("empty-art").resizable().scaledToFit().frame(width: 166, height: 152)
            Button(AppCopy.text("新建房源"), action: add).buttonStyle(SetupButtonStyle())
                .accessibilityIdentifier("home.add")
        }.padding(.horizontal, 24).padding(.top, 56)
    }
}
