import SwiftUI

/// Matches WeChat's 51 by 31 switch while preserving native switch accessibility.
struct MPSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label.foregroundStyle(XJTheme.ink)
            Spacer(minLength: 8)
            Button { configuration.isOn.toggle() } label: {
                Capsule().fill(configuration.isOn ? XJTheme.primary : Color(white: 0.9))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 27, height: 27).padding(2)
                            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    }.frame(width: 51, height: 31)
            }.buttonStyle(.plain)
        }.accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        }
    }
}
