import SwiftUI

@main
struct XunjuApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let id = TouchTrailReviewHost.sessionID(ProcessInfo.processInfo.arguments) {
                TouchTrailReviewHost(defaults: TouchTrailReviewHost.defaults(for: id))
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .preferredColorScheme(.light)
            } else if let route = MPReviewRoute.parse(ProcessInfo.processInfo.arguments) {
                MPReviewHost(route: route, state: MPReviewRoute.state(ProcessInfo.processInfo.arguments))
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .preferredColorScheme(.light)
            } else if let surface = ReviewSurface.parse(ProcessInfo.processInfo.arguments) {
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
