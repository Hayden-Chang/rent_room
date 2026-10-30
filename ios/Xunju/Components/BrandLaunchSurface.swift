import SwiftUI

/// A static brand composition. Startup timing and navigation belong to the app.
struct BrandLaunchSurface: View {
    var body: some View {
        ZStack {
            XJTheme.background

            Image("brand-launch-icon")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .contentShape(.accessibility, RoundedRectangle(cornerRadius: 26, style: .continuous))
                .accessibilityLabel("寻居")
                .accessibilityIdentifier("brandLaunch.icon")
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("brandLaunch.surface")
    }
}

#Preview {
    BrandLaunchSurface().preferredColorScheme(.light)
}
