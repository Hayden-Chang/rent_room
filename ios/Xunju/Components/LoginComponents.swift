import AuthenticationServices
import SwiftUI

struct LoginEntryCard: View {
    var used = 0
    var limit = 1
    var appleReady = true
    var appleRequest: (ASAuthorizationAppleIDRequest) -> Void
    var appleCompletion: (Result<ASAuthorization, Error>) -> Void
    var capacity: () -> Void = {}

    var body: some View {
        XJCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("未登录也可记录看房").font(.system(size: 18, weight: .semibold)).frame(height: 27, alignment: .leading).padding(.bottom, 8)
                Text("登录后可购买扩容或恢复已购容量")
                    .font(.system(size: 13)).foregroundStyle(XJTheme.muted).frame(height: 19.5, alignment: .leading)
                SignInWithAppleButton(.signIn, onRequest: appleRequest, onCompletion: appleCompletion)
                    .signInWithAppleButtonStyle(.black).frame(height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("login.apple").padding(.top, 16).disabled(!appleReady)
                Rectangle().fill(XJTheme.line).frame(height: 1).padding(.top, 16)
                Button(action: capacity) { HStack {
                    Text("房源容量").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("\(used) / \(limit) 套 ›").font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted)
                }.frame(minHeight: 30).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityIdentifier("settings.capacity").padding(.top, 14)
            }.foregroundStyle(XJTheme.ink)
        }
    }
}
