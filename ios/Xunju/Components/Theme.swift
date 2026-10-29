import SwiftUI

// Values come from apps/wechat/src/app.wxss at the parity baseline.
enum XJTheme {
    static let background = Color(red: 245 / 255, green: 247 / 255, blue: 251 / 255)
    static let ink = Color(red: 28 / 255, green: 38 / 255, blue: 56 / 255)
    static let muted = Color(red: 102 / 255, green: 113 / 255, blue: 135 / 255)
    static let primary = Color(red: 77 / 255, green: 86 / 255, blue: 223 / 255)
    static let soft = Color(red: 236 / 255, green: 238 / 255, blue: 255 / 255)
    static let line = Color(red: 229 / 255, green: 233 / 255, blue: 241 / 255)
    static let danger = Color(red: 187 / 255, green: 65 / 255, blue: 73 / 255)
    static let dangerBackground = Color(red: 255 / 255, green: 240 / 255, blue: 239 / 255)
}

struct XJButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .foregroundStyle(primary ? .white : XJTheme.primary)
            .background(primary ? XJTheme.primary : XJTheme.soft)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct XJCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content.padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct XJIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image(name).resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
