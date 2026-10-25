import SwiftUI
import Observation

@MainActor @Observable final class WheelInputPresentation {
    struct Target: Identifiable {
        let id = UUID()
        let houseID: String
        let field: JSONValue
        let store: NativeStore
    }
    var target: Target?

    func open(houseID: String, field: JSONValue, store: NativeStore) {
        guard WheelFieldSpec.all[field.id] != nil, !store.house(houseID)["archived"].bool else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        target = Target(houseID: houseID, field: field, store: store)
    }
    func save(_ value: String, store: NativeStore) throws {
        guard let target, let spec = WheelFieldSpec.all[target.field.id] else { return }
        guard target.store === store, !store.house(target.houseID)["archived"].bool else {
            throw CoreFailure(message: "房源或账号已变化，请重新选择")
        }
        if spec.key(target.field["value"].string) != spec.key(value) {
            try store.answer(target.houseID, field: target.field.id, value: .string(value))
            if !store.status.error.isEmpty { throw CoreFailure(message: store.status.error) }
        }
        self.target = nil
    }
}

private struct WheelInputPresentationKey: EnvironmentKey {
    static let defaultValue: WheelInputPresentation? = nil
}
extension EnvironmentValues {
    var wheelInput: WheelInputPresentation? {
        get { self[WheelInputPresentationKey.self] }
        set { self[WheelInputPresentationKey.self] = newValue }
    }
}
