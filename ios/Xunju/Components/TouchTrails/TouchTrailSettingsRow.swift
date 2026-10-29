import SwiftUI

enum TouchTrailPreference {
    static let key = "presentation.touch-trails.enabled"
    static let defaultValue = false
}

struct TouchTrailSettingsRow: View {
    @AppStorage(TouchTrailPreference.key) private var isEnabled = TouchTrailPreference.defaultValue

    init(defaults: UserDefaults = .standard) {
        _isEnabled = AppStorage(wrappedValue: TouchTrailPreference.defaultValue, TouchTrailPreference.key, store: defaults)
    }

    var body: some View {
        Toggle("显示触摸轨迹", isOn: $isEnabled)
            .font(.system(size: 14, weight: .medium))
            .toggleStyle(MPSwitchStyle())
            .frame(minHeight: 50)
            .accessibilityIdentifier("settings.touch-trails")
    }
}
