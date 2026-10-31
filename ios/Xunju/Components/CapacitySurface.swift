import SwiftUI

enum CapacityActivity: String, CaseIterable {
    case idle, loading, purchasing, restoring, pending
    var busy: Bool { [.loading, .purchasing, .restoring].contains(self) }
}
