#if DEBUG
import SwiftUI

struct SpeedConsentReviewHost: View {
    @State private var prompt: SpeedConsentRequest? = SpeedConsentRequest(kind: .wifi)
    @State private var mobile = true
    @State private var event = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SpeedStatusCard(state: .preparing, reading: nil, cancel: { prompt = nil; event = "已取消，原答案保持不变" }, retry: {}, save: {})
                if !event.isEmpty { Text(event).font(.system(size: 13)).accessibilityIdentifier("review.consentEvent") }
                Button("重新检查网络") { prompt = SpeedConsentRequest(kind: .wifi); event = "" }.buttonStyle(XJButtonStyle())
                Toggle("评审移动网络", isOn: $mobile).font(.system(size: 13))
                Spacer()
            }.padding(16).padding(.top, 8).background(XJTheme.background)
                .navigationTitle("网速测试").navigationBarTitleDisplayMode(.inline)
                .background {
                    SpeedNetworkConsent(request: prompt) { id, accepted in
                        guard prompt?.id == id else { return }
                        let previous = prompt?.kind; prompt = nil
                        if accepted, previous == .wifi, mobile { prompt = SpeedConsentRequest(kind: .mobile) }
                        else { event = accepted ? "网络确认完成；评审不会下载数据" : "暂不测试，原答案保持不变" }
                    }.frame(width: 0, height: 0)
                }
        }.tint(XJTheme.primary)
    }
}
#endif
