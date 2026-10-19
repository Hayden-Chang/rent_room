import AuthenticationServices
import SwiftUI

enum PhoneLoginValidation {
    static func validPhone(_ value: String) -> Bool {
        value.range(of: "\\A1[3-9][0-9]{9}\\z", options: .regularExpression) != nil
    }

    static func validCode(_ value: String) -> Bool {
        value.range(of: "\\A[0-9]{6}\\z", options: .regularExpression) != nil
    }
}

struct LoginEntryCard: View {
    var wechat: () -> Void
    var phone: () -> Void
    var appleRequest: (ASAuthorizationAppleIDRequest) -> Void
    var appleCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        XJCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("未登录也可记录看房").font(.system(size: 18, weight: .semibold)).padding(.bottom, 8)
                Text("登录后可购买扩容或恢复已购容量")
                    .font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                Button("微信登录", action: wechat).buttonStyle(XJButtonStyle(primary: true))
                    .accessibilityIdentifier("login.wechat").padding(.top, 16)
                Button("手机号登录", action: phone).buttonStyle(XJButtonStyle())
                    .accessibilityIdentifier("login.phone").padding(.top, 12)
                SignInWithAppleButton(.signIn, onRequest: appleRequest, onCompletion: appleCompletion)
                    .signInWithAppleButtonStyle(.black).frame(height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("login.apple").padding(.top, 12)
                Rectangle().fill(XJTheme.line).frame(height: 1).padding(.top, 16)
                HStack {
                    Text("房源容量").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("0 / 2 套 ›").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                }.padding(.top, 14)
            }.foregroundStyle(XJTheme.ink)
        }
    }
}

struct PhoneLoginForm: View {
    var requestCode: (String) async throws -> Void
    var submit: (String, String) async throws -> Void
    @State private var phone = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var codeRequested = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("手机号登录").font(.system(size: 17, weight: .semibold))
            Text("手机号").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
            HStack(spacing: 12) {
                Text("+86").font(.system(size: 14))
                TextField("请输入手机号", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    .accessibilityIdentifier("phone.number")
            }.padding(.horizontal, 12).frame(height: 44).background(.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
            HStack(spacing: 8) {
                TextField("请输入6位验证码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .padding(.horizontal, 12).frame(height: 44).background(.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                    .accessibilityIdentifier("phone.code")
                Button("获取验证码") { perform { try await requestCode(phone); codeRequested = true } }
                    .font(.system(size: 13)).padding(.horizontal, 12).frame(height: 44)
                    .background(XJTheme.soft).foregroundStyle(XJTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(busy || !PhoneLoginValidation.validPhone(phone))
                    .opacity(PhoneLoginValidation.validPhone(phone) ? 1 : 0.45)
                    .accessibilityIdentifier("phone.request")
            }
            if codeRequested { Text("验证码已发送，请查收短信").font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("phone.error")
            }
            Button(busy ? "正在处理…" : "登录") { perform { try await submit(phone, code) } }
                .buttonStyle(XJButtonStyle(primary: true))
                .disabled(busy || !PhoneLoginValidation.validPhone(phone) || !PhoneLoginValidation.validCode(code))
                .opacity(PhoneLoginValidation.validPhone(phone) && PhoneLoginValidation.validCode(code) ? 1 : 0.45)
                .accessibilityIdentifier("phone.submit")
            Spacer(minLength: 0)
        }.font(.system(size: 14)).foregroundStyle(XJTheme.ink).padding(20)
            .background(XJTheme.background)
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await operation() } catch { self.error = error.localizedDescription }
        }
    }
}
