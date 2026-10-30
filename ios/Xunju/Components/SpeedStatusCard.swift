import SwiftUI

enum SpeedDisplayState: Equatable {
    case preparing, testing, failed(String), saveError(String), done
    var active: Bool { self == .preparing || self == .testing }
    var message: String {
        switch self {
        case .failed(let text), .saveError(let text): text
        case .done: "测速结果已保存"
        default: ""
        }
    }
}

struct SpeedStatusCard: View {
    let state: SpeedDisplayState
    let reading: SpeedReading?
    var doneMessage = "测速结果已保存"
    let cancel: () -> Void, retry: () -> Void, save: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            AppText("下载速度").font(.system(size: 15)).foregroundStyle(XJTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                AppText(reading.map { String(format: "%.2f", $0.mbps) } ?? "—").font(.system(size: 52, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(XJTheme.primary).accessibilityIdentifier("speed.value")
                AppText("Mbps").font(.system(size: 15)).foregroundStyle(XJTheme.muted)
            }.padding(.top, 34).padding(.bottom, 38)
            GeometryReader { geometry in
                Capsule().fill(XJTheme.soft)
                Capsule().fill(XJTheme.primary).frame(width: geometry.size.width * max(0, min(100, reading?.progress ?? 0)) / 100)
            }.frame(height: 6).accessibilityLabel(AppCopy.text("测速进度")).accessibilityValue(AppCopy.text("\(Int(reading?.progress ?? 0))%"))
            if !state.message.isEmpty {
                AppText(state == .done ? doneMessage : state.message).font(.system(size: 14)).foregroundStyle(XJTheme.muted).lineSpacing(4)
                    .multilineTextAlignment(.center).padding(.top, 24).accessibilityIdentifier("speed.message")
            }
            if state != .done {
                Button(AppCopy.text(state.active ? "取消" : (isSaveError ? "重试保存" : "重新测速")), action: state.active ? cancel : (isSaveError ? save : retry))
                    .font(.system(size: 15)).foregroundStyle(state.active ? XJTheme.muted : XJTheme.primary)
                    .padding(.horizontal, 28).frame(minHeight: 44).background(state.active ? XJTheme.background : XJTheme.soft)
                    .clipShape(Capsule()).padding(.top, 24).accessibilityIdentifier("speed.action")
            }
        }.frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 20)
            .background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(XJTheme.line))
    }
    private var isSaveError: Bool { if case .saveError = state { true } else { false } }
}
