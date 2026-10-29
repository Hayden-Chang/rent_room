#if DEBUG
import SwiftUI

// Isolated review of the settings footer and input observation, before page integration.
// Every run uses its own preferences; it never opens or modifies housing records.
struct TouchTrailReviewHost: View {
    let defaults: UserDefaults

    static func sessionID(_ arguments: [String]) -> UUID? {
        guard let index = arguments.firstIndex(of: "--touch-trail-review"),
              arguments.indices.contains(index + 1) else { return nil }
        return UUID(uuidString: arguments[index + 1])
    }

    static func defaults(for id: UUID) -> UserDefaults {
        UserDefaults(suiteName: "TouchTrailReview." + id.uuidString)!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("数据与备份").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(XJTheme.ink).padding(.top, 8)
                    XJCard { VStack(spacing: 0) { row("导入房源"); row("导出房源") } }
                    XJCard { row("权限管理") }
                    XJCard { VStack(spacing: 0) { row("使用反馈"); row("分享看房搭子") } }
                    XJCard { TouchTrailSettingsRow(defaults: defaults) }
                    XJCard {
                        HStack { Text("版本"); Spacer(); Text("0.1.0").foregroundStyle(XJTheme.muted) }
                            .font(.system(size: 14)).frame(minHeight: 50)
                            .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
                            .accessibilityIdentifier("review.version")
                    }
                }.padding(16)
            }.background(XJTheme.background).navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("交互检查") { TouchTrailGestureReview() }.accessibilityIdentifier("review.gestures")
                    }
                }
        }.tint(XJTheme.primary)
            .overlay { TouchTrailPresentation(defaults: defaults) }
    }

    private func row(_ title: String) -> some View {
        HStack {
            Text(title).fontWeight(.medium)
            Spacer()
            Text("›").foregroundStyle(XJTheme.muted)
        }.font(.system(size: 14)).foregroundStyle(XJTheme.ink).frame(minHeight: 50)
            .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
    }
}

private struct TouchTrailGestureReview: View {
    @State private var answer = MPFieldState()
    @State private var coordinator = MPSwipeCoordinator()
    @State private var event = "尚未操作"
    @State private var sheet = false
    @State private var fullScreen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                XJCard {
                    MPFieldRow(item: MPFieldItem(id: "touch-review", title: "纱窗正常", options: ["是", "否", "没有"]),
                        state: $answer, coordinator: coordinator,
                        note: { event = "已打开备注" }, capture: { event = "已触发拍摄" })
                }
                Text(event).accessibilityIdentifier("review.event")
                Button("打开半屏弹层") { sheet = true }.accessibilityIdentifier("review.sheet")
                Button("打开全屏弹层") { fullScreen = true }.accessibilityIdentifier("review.fullscreen")
                ForEach(0..<18) { index in
                    XJCard { HStack { Text("滚动检查 \(index + 1)"); Spacer() }.frame(height: 40) }
                        .accessibilityIdentifier("review.scroll.\(index)")
                }
                Text("已到列表底部").accessibilityIdentifier("review.bottom")
            }.padding(16)
        }.background(XJTheme.background).navigationTitle("触摸轨迹交互检查").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $sheet) { modal("半屏弹层", close: { sheet = false }).presentationDetents([.medium]) }
            .fullScreenCover(isPresented: $fullScreen) { modal("全屏弹层", close: { fullScreen = false }) }
    }

    private func modal(_ title: String, close: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            Text(title).font(.headline).accessibilityIdentifier("review.modal.title")
            Text(event).accessibilityIdentifier("review.modal.event")
            Button("检查点击") { event = title + "点击成功" }.accessibilityIdentifier("review.modal.tap")
            Button("关闭", action: close).accessibilityIdentifier("review.modal.close")
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(XJTheme.background)
    }
}
#endif
