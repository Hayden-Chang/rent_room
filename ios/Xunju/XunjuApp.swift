import SwiftUI

@main
struct XunjuApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let route = LocalSettingsReviewRoute.parse(ProcessInfo.processInfo.arguments) {
                if route == .developmentCredits || route == .developmentCreditsFailure {
                    DevelopmentCreditsReviewHost(failGrant: route == .developmentCreditsFailure)
                } else {
                    LocalSettingsReviewHost(route: route)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
            } else if let route = MPReviewRoute.parse(ProcessInfo.processInfo.arguments) {
                MPReviewHost(route: route, state: MPReviewRoute.state(ProcessInfo.processInfo.arguments))
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .preferredColorScheme(.light)
            } else if let surface = ReviewSurface.parse(ProcessInfo.processInfo.arguments) {
                ComponentReviewHost(surface: surface)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .preferredColorScheme(.light)
            } else if AppWorkspace.isBusinessTest && ProcessInfo.processInfo.arguments.contains("--review-settings") {
                AppStoreReviewHost(usesSettingsPage: true)
            } else {
                AppRoot()
            }
            #else
            AppRoot()
            #endif
        }
    }

}
