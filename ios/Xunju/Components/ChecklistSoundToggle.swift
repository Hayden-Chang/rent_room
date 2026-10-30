import SwiftUI

struct ChecklistSoundToggle: View {
    @Binding var enabled: Bool

    var body: some View {
        Button { enabled.toggle() } label: {
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 22, height: 22)
                .overlay {
                    if !enabled {
                        Path { path in
                            path.move(to: CGPoint(x: 20, y: 2))
                            path.addLine(to: CGPoint(x: 2, y: 20))
                        }.stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(XJTheme.ink)
        .accessibilityLabel(enabled ? "关闭声音" : "开启声音")
        .accessibilityValue(enabled ? "已开启" : "已关闭")
        .accessibilityIdentifier("checklist.sound.toggle")
    }
}
