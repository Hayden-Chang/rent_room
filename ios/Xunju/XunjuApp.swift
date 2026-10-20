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
                AppRoot()
            }
            #else
            AppRoot()
            #endif
        }
    }

}
