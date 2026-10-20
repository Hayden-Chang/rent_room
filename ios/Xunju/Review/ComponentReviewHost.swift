#if DEBUG
import SwiftUI

enum ReviewSurface: String {
    case homes, checklist, account, fields, summary, place, routes, speed, coach
    case speedConsent = "speed-consent"

    var utilities: Bool { [.place, .routes, .speed, .coach, .speedConsent].contains(self) }

    static func parse(_ arguments: [String]) -> ReviewSurface? {
        guard let index = arguments.firstIndex(of: "--component-review"),
              arguments.indices.contains(index + 1) else { return nil }
        return ReviewSurface(rawValue: arguments[index + 1])
    }
}

// The host exercises isolated production components. It owns only disposable
// fixture state and never writes records, grants capacity, or authenticates.
struct ComponentReviewHost: View {
    let surface: ReviewSurface
    @State private var empty = false
    @State private var expanded = false
    @State private var windowScreen = ""
    @State private var windowSeal = "是"
    @State private var flagged = false
    @State private var phoneVisible = false
    @State private var event = ""

    var body: some View {
        if surface.utilities {
            UtilityReviewHost(surface: surface)
        } else {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    switch surface {
                    case .homes: homes
                    case .checklist: checklist
                    case .account: account
                    case .fields: AnswerReviewHost()
                    case .summary: SummaryReviewHost()
                    case .place, .routes, .speed, .coach, .speedConsent: EmptyView()
                    }
                    if !event.isEmpty {
                        Text(event).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                            .accessibilityIdentifier("review.event")
                    }
                }.padding(16)
            }.background(XJTheme.background)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(XJTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    if surface == .homes {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(empty ? "房源卡片" : "空状态") { empty.toggle() }
                                .accessibilityIdentifier("review.toggleEmpty")
                        }
                    }
                }
                .sheet(isPresented: $phoneVisible) {
                    NavigationStack {
                        PhoneLoginForm(requestCode: { _ in throw unavailable }, submit: { _, _ in throw unavailable })
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("关闭") { phoneVisible = false }.accessibilityIdentifier("phone.close")
                                }
                            }
                    }.presentationDetents([.large])
                }
        }.tint(XJTheme.primary)
        }
    }

    private var title: String {
        switch surface {
        case .homes: "我的房源"
        case .checklist: "清单组件"
        case .account: "登录组件"
        case .fields: "清单输入组件"
        case .summary: "看房总结组件"
        case .place: "地点组件"
        case .routes: "通勤组件"
        case .speed: "测速组件"
        case .coach: "操作引导组件"
        case .speedConsent: "测速网络确认"
        }
    }

    @ViewBuilder private var homes: some View {
        if empty {
            EmptyHouseState { event = "已触发添加房源" }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                HouseCard(house: HouseCardContent(name: "阳光小区 · 1号房", rent: "2800", address: "朝阳路18号",
                                                 area: "45", decision: "", done: 0, total: 302, issues: 0)) {
                    event = "已触发打开1号房"
                }.accessibilityIdentifier("house.first")
                HouseCard(house: HouseCardContent(name: "地铁旁 · 2号房", rent: "3200", address: "新城路8号",
                                                 area: "56", decision: "继续比较", done: 38, total: 302, issues: 2)) {
                    event = "已触发打开2号房"
                }
            }
        }
    }

    private var checklist: some View {
        ChecklistDisclosure(title: "墙面地面与门窗", progress: "\(windowScreen.isEmpty ? 1 : 2) / 2", expanded: $expanded) {
            InspectionChoiceRow(title: "纱窗正常", options: ["正常", "有问题", "没有"],
                                choiceLabels: ["正常": "是", "有问题": "否"], value: $windowScreen,
                                flagged: $flagged, note: { event = "已触发纱窗备注" }, capture: { event = "已触发纱窗拍摄" })
            InspectionChoiceRow(title: "密封条正常", options: ["是", "否"], value: $windowSeal,
                                flagged: .constant(false), note: {}, capture: {})
        }
    }

    private var account: some View {
        LoginEntryCard(wechat: { event = "已触发微信登录入口" }, phone: { phoneVisible = true }, appleRequest: { request in
            request.requestedScopes = [.email, .fullName]
        }, appleCompletion: { result in
            switch result {
            case .success: event = "Apple 授权已返回，尚未建立应用账号"
            case .failure: event = "Apple 授权未完成"
            }
        })
    }

    private var unavailable: NSError {
        NSError(domain: "XunjuComponentReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "短信登录服务尚未接通，请稍后再试"])
    }
}
#endif
