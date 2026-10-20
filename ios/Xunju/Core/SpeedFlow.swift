import Foundation
import Observation

/// Page lifetime and consent ownership. A stale alert cannot accept a newer run.
@MainActor @Observable final class SpeedFlow {
    let session: SpeedSession
    let network: NativeNetwork
    private(set) var prompt: SpeedConsentRequest?
    private(set) var closeRequested = false
    private var preparingNetwork = false
    private var preparationError = ""
    @ObservationIgnored private var reply: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var active = true

    init(session: SpeedSession, network: NativeNetwork) { self.session = session; self.network = network }
    var state: SpeedDisplayState {
        if preparingNetwork { return .preparing }
        return preparationError.isEmpty ? session.state : .failed(preparationError)
    }
    @discardableResult func start() -> Task<Void, Never>? {
        guard active, operation == nil else { return nil }
        epoch += 1; let version = epoch
        preparingNetwork = true; preparationError = ""; closeRequested = false
        operation = Task { @MainActor in
            defer { if epoch == version { operation = nil; preparingNetwork = false } }
            do {
                let status = try await network.ready()
                try Task.checkCancellation(); guard active, epoch == version else { return }
                preparingNetwork = false
                let measurement = session.start(network: status) { [weak self] kind in
                    guard let self else { return false }
                    return await ask(kind)
                }
                await measurement?.value
                if active, epoch == version, session.state == .done { closeRequested = true }
            } catch is CancellationError {} catch {
                if active, epoch == version { preparationError = error.localizedDescription }
            }
        }
        return operation
    }
    private func ask(_ kind: SpeedConsentKind) async -> Bool {
        let request = SpeedConsentRequest(kind: kind)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { reply in
                guard active, !Task.isCancelled else { reply.resume(returning: false); return }
                self.reply = reply; prompt = request
            }
        } onCancel: { Task { @MainActor in self.resolve(request.id, accepted: false) } }
    }
    func answer(_ id: UUID, accepted: Bool) {
        guard prompt?.id == id else { return }
        resolve(id, accepted: accepted)
        if !accepted { closeRequested = true }
    }
    private func resolve(_ id: UUID, accepted: Bool) {
        guard prompt?.id == id else { return }
        let pending = reply; reply = nil; prompt = nil
        pending?.resume(returning: accepted)
    }
    func networkChanged(to version: Int) {
        if session.networkChanged(to: version) { cancel() }
    }
    func save() {
        guard active else { return }
        session.save(); if session.state == .done { closeRequested = true }
    }
    func cancel(close: Bool = false, leaving: Bool = false) {
        epoch += 1; operation?.cancel(); operation = nil
        session.cancel(); preparingNetwork = false; preparationError = ""
        if let prompt { resolve(prompt.id, accepted: false) }
        if leaving { active = false; network.stop() }
        if close { closeRequested = true }
    }
}
