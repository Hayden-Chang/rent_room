#if DEBUG
import SwiftUI

// Keep the original review route on the same presentation as production.
struct CapacityReviewHost: View {
    var body: some View { PropertyCreditsReviewHost() }
}
#endif
