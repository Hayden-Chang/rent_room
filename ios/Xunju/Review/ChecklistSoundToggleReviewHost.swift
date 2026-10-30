#if DEBUG
import SwiftUI

// Only the real header and toggle are under review. Fixture choices never write
// house data or preferences; the approved toggle is integrated in a later step.
struct ChecklistSoundToggleReviewHost: View {
    @State private var enabled = true
    @State private var backCount = 0
    @State private var seal = MPFieldState(selected: ["是"])
    @State private var screen = MPFieldState()
    @State private var coordinator = MPSwipeCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            MPCard {
                VStack(spacing: 0) {
                    MPFieldRow(item: MPFieldItem(id: "seal", title: "窗户密封正常", options: ["是", "否", "不涉及"]),
                               state: $seal, readonly: false, coordinator: coordinator, note: {}, capture: {})
                    MPFieldRow(item: MPFieldItem(id: "screen", title: "纱窗正常", options: ["是", "否", "没有"]),
                               state: $screen, readonly: false, coordinator: coordinator, note: {}, capture: {})
                }
            }.padding(16)
            Spacer()
            if backCount > 0 { Text("已返回").accessibilityIdentifier("sound-toggle.back") }
        }
        .background(XJTheme.background)
        .miniNavigation("阳光小区 · 1号房", back: { backCount += 1 }) {
            ChecklistSoundToggle(enabled: $enabled)
        }
        .accessibilityIdentifier("sound-toggle.review")
    }
}
#endif
