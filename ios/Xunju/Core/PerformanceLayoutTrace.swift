import SwiftUI

// Temporary bounded diagnostics; removed after identifying the update cycle.
@MainActor enum PerformanceLayoutTrace {
    private static var counts: [String: Int] = [:]
    static func body<V: View>(_ type: V.Type, _ context: String = "") {
        let key = String(describing: type) + ":" + context
        let count = counts[key, default: 0]
        counts[key] = count + 1
        if count < 80 { print("LAYOUT \(key) #\(count)"); V._printChanges() }
    }
    static func event(_ message: String) { print("LAYOUT EVENT \(message)") }
    static func modifier(_ key: String) {
        let count = counts[key, default: 0]; counts[key] = count + 1
        if count < 80 { print("LAYOUT \(key) #\(count)") }
    }
}
