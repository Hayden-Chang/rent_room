#if DEBUG
import SwiftUI

struct TouchMenuReviewHost: View {
    @State private var anchor: CGPoint?
    @State private var event = "等待操作"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) { card("left", name: "阳光小区"); card("right", name: "地铁旁") }
                Spacer(minLength: 12)
                Text(event).accessibilityIdentifier("touch-menu.event")
                HStack(spacing: 12) { card("bottom-left", name: "朝南一居"); card("bottom-right", name: "安静小区") }
            }.padding(16).background(XJTheme.background)
                .miniNavigation(AppCopy.text("我的房源"), showsBack: false)
                .overlay {
                    if let anchor {
                        TouchActionMenu(anchor: anchor, actions: [
                            ("重命名", false, { choose("重命名") }),
                            ("删除", true, { choose("删除") }),
                            ("导出房源 ZIP", false, { choose("导出房源 ZIP") })
                        ], close: { self.anchor = nil })
                    }
                }
        }
    }

    private func card(_ id: String, name: String) -> some View {
        HouseCard(house: HouseCardContent(name: name, rent: "2800", address: "朝阳路18号", area: "45",
                                         decision: "", done: 0, total: 302, issues: 0)) { event = "打开" }
            .accessibilityIdentifier("touch-menu.card.\(id)")
            .modifier(TouchMenuPressActions(tap: { event = "打开" }, hold: { anchor = $0 }))
    }

    private func choose(_ value: String) { event = value; anchor = nil }
}
#endif
