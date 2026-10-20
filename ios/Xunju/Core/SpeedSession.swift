import Foundation
import Observation

struct NetworkStatus: Equatable, Sendable {
    let available: Bool, wifi: Bool, version: Int
}

/// Owns measurement and guarded persistence, independently of alerts and pages.
/// The UI must supply explicit consent; no measurement starts from a callback alone.
@MainActor @Observable final class SpeedSession {
    private(set) var state: SpeedDisplayState = .preparing
    private(set) var reading: SpeedReading?
    @ObservationIgnored private let store: NativeStore
    @ObservationIgnored private let id: String
    @ObservationIgnored private let validScope: () -> Bool
    @ObservationIgnored private let test: NativeSpeedTest
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var previous: JSONValue = .null
    @ObservationIgnored private var result: SpeedReading?
    @ObservationIgnored private var networkVersion = 0

    init(store: NativeStore, houseID: String, test: NativeSpeedTest = NativeSpeedTest(transport: NativeSpeedTransport()), validScope: @escaping () -> Bool) {
        self.store = store; id = houseID; self.test = test; self.validScope = validScope
    }
    @discardableResult func start(network: NetworkStatus, consent: @escaping @MainActor (SpeedConsentKind) async -> Bool) -> Task<Void, Never>? {
        guard operation == nil else { return nil }
        epoch += 1; let version = epoch
        networkVersion = network.version
        state = .preparing; reading = nil; result = nil
        operation = Task { @MainActor in
            defer { if epoch == version { operation = nil } }
            do {
                try editable()
                previous = store.house(id)["answers"][UtilityField.speed]["value"]
                guard network.available else { throw CoreFailure(message: "当前无网络，请连接 Wi-Fi 后重试") }
                guard await consent(.wifi) else { throw CancellationError() }
                try Task.checkCancellation(); guard epoch == version else { return }
                if !network.wifi {
                    guard await consent(.mobile) else { throw CancellationError() }
                    try Task.checkCancellation(); guard epoch == version else { return }
                }
                try editable(); state = .testing
                let measured = try await test.run { [weak self] progress in
                    await self?.update(progress, version: version)
                }
                try Task.checkCancellation(); guard epoch == version else { return }
                result = measured; reading = measured; save()
            } catch is CancellationError {
                if epoch == version { state = .failed("测速已取消，原值保持不变") }
            } catch { if epoch == version { state = .failed(error.localizedDescription) } }
        }
        return operation
    }
    private func update(_ value: SpeedReading, version: Int) {
        if epoch == version && validScope() { reading = value }
    }
    func save() {
        guard let result else { return }
        do {
            try editable()
            try store.call("computed", ["id": .string(id), "field": .string(UtilityField.speed),
                                        "value": .object(["amount": .number(result.mbps), "previous": previous])])
            self.result = nil; state = .done
        } catch { state = .saveError(error.localizedDescription) }
    }
    private func editable() throws {
        guard validScope(), store.house(id) != .null, !store.house(id)["archived"].bool,
              try store.call("targets", ["id": .string(id)]).array.contains(where: { $0.id == UtilityField.speed }) else {
            throw CoreFailure(message: "房源不可编辑，请返回清单")
        }
    }
    @discardableResult func networkChanged(to version: Int) -> Bool {
        guard operation != nil && version != networkVersion && state.active else { return false }
        cancel(); return true
    }
    func cancel() {
        epoch += 1; operation?.cancel(); operation = nil; result = nil
        if state.active { state = .failed("测速已取消，原值保持不变") }
    }
}
