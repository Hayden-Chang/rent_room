import Foundation
import Observation

@MainActor @Observable final class CapacityController {
    private(set) var activity = CapacityActivity.idle
    private(set) var error = ""
    private(set) var product: CapacityProduct?
    @ObservationIgnored private weak var workspace: AppWorkspace?
    @ObservationIgnored private let api: any CapacityServicing
    @ObservationIgnored private let storefront: any CapacityStorefront
    @ObservationIgnored private var identity: PurchaseIdentity?
    @ObservationIgnored private var context: CapacityContext?
    @ObservationIgnored private var verifications: [String: Task<CapacityConfirmation, Error>] = [:]
    @ObservationIgnored private var finished: Set<String> = []
    @ObservationIgnored private var pending = false
    @ObservationIgnored private var awaitingApproval = false
    init(workspace: AppWorkspace, api: any CapacityServicing, storefront: any CapacityStorefront) {
        self.workspace = workspace; self.api = api; self.storefront = storefront
    }
    func identityChanged() {
        identity = nil; context = nil; product = nil; pending = false; awaitingApproval = false; error = ""; activity = .idle
    }
    /// Called only while the user is in the capacity flow, never on app launch.
    func start() {
        storefront.observe { [weak self] transaction in
            guard let self, let identity = self.identity, self.matches(transaction) else { return }
            do {
                try await self.confirm(transaction, identity: identity)
                if self.current(identity) {
                    self.pending = false; self.awaitingApproval = false
                    if !self.activity.busy { self.activity = .idle }; self.error = ""
                }
            } catch {
                if self.current(identity) {
                    self.pending = true; self.error = error.localizedDescription
                    if !self.activity.busy { self.activity = .pending }
                }
            }
        }
    }
    func stop() { storefront.stopObserving() }
    func load() async {
        guard !activity.busy else { return }
        activity = .loading; error = ""
        defer { activity = pending ? .pending : .idle }
        do {
            let identity = try await prepare(loadProduct: true)
            for transaction in try await storefront.transactions(synchronize: false) where matches(transaction) {
                pending = true; try await confirm(transaction, identity: identity); pending = awaitingApproval
            }
        } catch is CancellationError {} catch { product = nil; self.error = error.localizedDescription }
    }
    func purchase() async {
        guard !activity.busy, !pending, product != nil, context?.available == true else { return }
        activity = .purchasing; error = ""
        defer { activity = pending ? .pending : .idle }
        do {
            let identity = try await prepare(loadProduct: true)
            guard let product, let context, context.available else { throw CoreFailure(message: "房源包暂未开放购买，请稍后再试") }
            switch try await storefront.purchase(product, accountToken: context.appAccountToken) {
            case .cancelled: break
            case .pending: if current(identity) { pending = true; awaitingApproval = true }
            case .verified(let transaction):
                guard current(identity) else { return }
                pending = true
                try await confirm(transaction, identity: identity)
                if current(identity) { pending = awaitingApproval }
            }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    func restore() async {
        guard !activity.busy else { return }
        activity = .restoring; error = ""
        defer { activity = pending ? .pending : .idle }
        do {
            let identity = try await prepare(loadProduct: false, refresh: true)
            for transaction in try await storefront.transactions(synchronize: true) where matches(transaction) {
                pending = true; try await confirm(transaction, identity: identity); pending = awaitingApproval
            }
            try apply(try await api.restore(proof: identity.signedAppTransaction), identity: identity)
            pending = awaitingApproval
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    private func current(_ value: PurchaseIdentity) -> Bool { identity == value }
    private func prepare(loadProduct: Bool, refresh: Bool = false) async throws -> PurchaseIdentity {
        let value = try await storefront.identity(refresh: refresh).validated()
        try Task.checkCancellation()
        if identity?.account != value.account || identity?.environment != value.environment {
            context = nil; product = nil; pending = false; awaitingApproval = false
        }
        identity = value
        let response = try await api.context(proof: value.signedAppTransaction)
        try Task.checkCancellation()
        try apply(response.balance, identity: value)
        context = response
        if loadProduct || !response.available { product = nil }
        if loadProduct, response.available, let id = response.productID {
            let loaded = try await storefront.product(id)
            guard current(value) else { throw CancellationError() }
            guard loaded.id == id else { throw CoreFailure(message: "房源包信息不一致") }
            product = loaded
        }
        return value
    }
    private func matches(_ transaction: CapacityTransaction) -> Bool {
        guard let context, let identity else { return false }
        return transaction.productID == context.productID && transaction.accountToken == context.appAccountToken
            && transaction.environment == identity.environment && transaction.appTransactionID == identity.appTransactionID
    }
    private func confirm(_ transaction: CapacityTransaction, identity: PurchaseIdentity) async throws {
        guard current(identity), matches(transaction) else { throw CoreFailure(message: "请使用购买时的 App Store 账号恢复容量") }
        let key = identity.account + ":" + transaction.environment + ":" + transaction.id
        let task: Task<CapacityConfirmation, Error>
        if let existing = verifications[key] { task = existing }
        else {
            task = Task { try await api.verify(transaction.id, proof: identity.signedAppTransaction) }
            verifications[key] = task
        }
        defer { verifications[key] = nil }
        let value = try await task.value
        guard value.transactionID == transaction.id, ["verified", "revoked"].contains(value.status) else { throw CoreFailure(message: "购买记录暂时无法确认") }
        try apply(value.balance, identity: identity)
        guard !finished.contains(key) else { return }
        finished.insert(key)
        await storefront.finish(transaction)
    }
    private func apply(_ balance: CapacityBalance, identity: PurchaseIdentity) throws {
        guard current(identity), let workspace else { throw CancellationError() }
        try workspace.applyPurchaseCapacity(balance, identity: identity)
    }
}
