import SwiftUI

enum TouchTrailPreference {
    static let key = "presentation.touch-trails.enabled"
    static let defaultValue = false

    // Reuse the existing opt-in business-test sandbox without changing normal launches.
    static func defaults(arguments: [String] = ProcessInfo.processInfo.arguments) -> UserDefaults {
        #if DEBUG
        if let index = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(index + 1),
           let id = UUID(uuidString: arguments[index + 1]) {
            return UserDefaults(suiteName: "TouchTrailBusinessTests." + id.uuidString)!
        }
        #endif
        return .standard
    }
}

struct TouchTrailSettingsRow: View {
    @AppStorage(TouchTrailPreference.key) private var isEnabled = TouchTrailPreference.defaultValue

    var body: some View {
        Toggle(AppCopy.text("显示触摸轨迹"), isOn: $isEnabled)
            .font(.system(size: 14, weight: .medium))
            .toggleStyle(MPSwitchStyle())
            .frame(minHeight: 50)
            .accessibilityIdentifier("settings.touch-trails")
    }
}
