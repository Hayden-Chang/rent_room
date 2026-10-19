import SwiftUI

@main
struct XunjuApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let surface = ReviewSurface.parse(ProcessInfo.processInfo.arguments) {
                ComponentReviewHost(surface: surface)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .preferredColorScheme(.light)
            } else {
                preparationView
            }
            #else
            preparationView
            #endif
        }
    }

    private var preparationView: some View {
        Text("寻居 · 看房手记")
            .foregroundStyle(XJTheme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(XJTheme.background)
    }
}
