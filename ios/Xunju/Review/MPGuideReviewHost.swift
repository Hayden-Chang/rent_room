#if DEBUG
import SwiftUI

struct MPGuideReviewHost: View {
    @State private var step = 1
    @State private var hide = false
    @State private var phase = "房源"
    @State private var tab = "清单"
    @State private var field = MPFieldState()
    @State private var coordinator = MPSwipeCoordinator()
    private let steps = [
        CoachStep(title: "房源信息", body: "记录名称、地址、租金等基本资料。\n「全部」会显示所有阶段的检查项。"),
        CoachStep(title: "现场检查", body: "到房子里逐项确认采光、家电、\n网络等实际情况。"),
        CoachStep(title: "询问与签约", body: "选好房源后，再确认合同、费用、\n交接等需要向房东询问的事项。"),
        CoachStep(title: "左滑检查项", body: "向左滑动一条检查项，即可\n标记问题、写备注或添加影像。")
    ]
    var body: some View {
        MPFrame(title: "阳光小区") {
            ScrollView {
                VStack(spacing: 14) {
                    MPCard {
                        HStack { Text("现场检查").font(.system(size: 17, weight: .semibold)); Spacer(); Text("86 / 302").font(.system(size: 14)) }.frame(height: 64)
                    }
                    HStack(spacing: 8) {
                        ForEach(Array(["全部", "房源", "现场", "询问签约"].enumerated()), id: \.offset) { index, title in
                            Text(title).font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(phase == title ? XJTheme.soft : .white).clipShape(Capsule())
                                .anchorPreference(key: CoachAnchors.self, value: .bounds) { index == 0 ? [:] : [index: $0] }
                        }
                    }
                    MPCard {
                        MPFieldRow(item: MPFieldItem(id: "guide", title: "窗户密封", options: ["是", "否"]), state: $field,
                            coordinator: coordinator, note: {}, capture: {})
                            .anchorPreference(key: CoachAnchors.self, value: .bounds) { [4: $0] }
                    }
                }.padding(16)
            }
        } footer: { MPTabBar(selection: $tab, detail: true, mediaCount: 4, issueCount: 3) }
            .accessibilityHidden(step <= 4)
            .overlayPreferenceValue(CoachAnchors.self) { anchors in
                GeometryReader { geometry in
                    if step <= 4 {
                        CoachOverlay(steps: steps, step: step, target: anchors[step].map { geometry[$0] }, fieldLabel: "窗户密封",
                            hideAutomatically: $hide, mediaIconSize: 22) {
                                step += 1
                                phase = step == 1 ? "房源" : step == 2 ? "现场" : step == 3 ? "询问签约" : "全部"
                            }
                    }
                }
            }
    }
}
#endif
