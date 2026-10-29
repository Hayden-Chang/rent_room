import SwiftUI

/// A static brand composition. Startup timing and navigation belong to the app.
struct BrandLaunchSurface: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 32
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize = 13
    @ScaledMetric(relativeTo: .footnote) private var taglineSize = 13

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                VStack(spacing: 0) {
                    Image("xiaoda-idle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .accessibilityHidden(true)
                        .padding(.bottom, 24)

                    Text("寻居")
                        .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                        .tracking(6)
                        .padding(.leading, 6)
                        .foregroundStyle(XJTheme.ink)
                        .accessibilityIdentifier("brandLaunch.title")

                    Text("看房手记")
                        .font(.system(size: subtitleSize, weight: .medium))
                        .tracking(4)
                        .padding(.leading, 4)
                        .foregroundStyle(XJTheme.muted)
                        .padding(.top, 12)
                        .accessibilityIdentifier("brandLaunch.subtitle")
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 32)
                Text("看房有记录，选家更有底")
                    .font(.system(size: taglineSize))
                    .foregroundStyle(XJTheme.muted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("brandLaunch.tagline")
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 32)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(XJTheme.background.ignoresSafeArea())
    }
}

#Preview {
    BrandLaunchSurface().preferredColorScheme(.light)
}
