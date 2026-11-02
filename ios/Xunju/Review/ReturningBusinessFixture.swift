#if DEBUG
import Foundation

/// A returning-user precondition for older business regression scenarios.
/// First-run tests omit this flag and must complete the actual setup and teaching.
enum ReturningBusinessFixture {
    static func suppressesSystemReview(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        enabled(arguments) && arguments.contains("--stub-system-review")
    }
    static func enabled(_ arguments: [String]) -> Bool {
        guard arguments.contains("--returning-business-fixture"), let index = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(index + 1) else { return false }
        return UUID(uuidString: arguments[index + 1]) != nil
    }
}
#endif
