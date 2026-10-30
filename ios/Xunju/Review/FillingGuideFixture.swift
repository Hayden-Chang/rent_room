#if DEBUG
import Foundation

/// Prepares the state immediately after teaching; filling still uses the real UI.
enum FillingGuideFixture {
    static func mode(_ arguments: [String]) -> String? {
        guard let test = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(test + 1),
              UUID(uuidString: arguments[test + 1]) != nil,
              let flag = arguments.firstIndex(of: "--filling-guide-fixture"), arguments.indices.contains(flag + 1),
              ["simple", "detailed"].contains(arguments[flag + 1]) else { return nil }
        return arguments[flag + 1]
    }
    @MainActor static func prepare(_ store: NativeStore, mode: String) throws {
        guard store.houses.isEmpty, store.state["xiaoda"]["setup"].string != "done" else { return }
        try store.call("setupFinish", ["value": .string(mode)])
        let id = try store.add("首次填写")
        for value in ["next", "next", "swiped", "next"] {
            try store.call("tutorialAdvance", ["id": .string(id), "value": .string(value)])
        }
    }
}
#endif
