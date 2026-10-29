import SwiftUI

/// The same standalone naming page as pages/new-house; the caller owns creation.
struct NewHouseSurface: View {
    @State var name: String
    let create: (String) throws -> Void
    @State private var error = ""
    @State private var busy = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                XiaodaMessage(text: "给这套房源起个名字吧～", pose: "greet", compact: false) { EmptyView() }
                TextField("例如：阳光花园3栋", text: $name)
                    .font(.system(size: 16)).padding(.horizontal, 16).frame(height: 56)
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(red: 222/255, green: 223/255, blue: 240/255), lineWidth: 2))
                    .padding(.top, 28).padding(.bottom, 20)
                    .submitLabel(.done).onSubmit(save).accessibilityIdentifier("prompt.text")
                    .onChange(of: name) { _, value in name = String(value.prefix(80)); error = "" }
                if !error.isEmpty { Text(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.dangerBackground).clipShape(RoundedRectangle(cornerRadius: 10)).padding(.bottom, 12).accessibilityIdentifier("prompt.error") }
                Button(action: save) { if busy { ProgressView() } else { Text("创建房源") } }
                    .buttonStyle(SetupButtonStyle()).disabled(busy).accessibilityIdentifier("prompt.confirm")
            }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 40)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(.white).miniNavigation("新建房源", background: .white)
    }
    private func save() {
        PerformanceLayoutTrace.event("create pressed busy=\(busy) name=\(name)")
        guard !busy else { return }
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { error = "请填写房源名称。"; return }
        busy = true
        defer { busy = false }
        do { try create(value); PerformanceLayoutTrace.event("create succeeded, dismissing"); dismiss() } catch { PerformanceLayoutTrace.event("create failed \(error)"); self.error = error.localizedDescription }
    }
}
