import Foundation
import Observation

@MainActor @Observable final class CapacityController {
    private(set) var activity = CapacityActivity.idle
    private(set) var error = ""
    private(set) var product: CapacityProduct?
    @ObservationIgnored private weak var workspace: AppWorkspace?
    @ObservationIgnored private let storefront: any CapacityStorefront
    @ObservationIgnored private var identity: PurchaseIdentity?
    @ObservationIgnored private var finished: Set<String> = []
    @ObservationIgnored private var pending = false
    @ObservationIgnored private var awaitingApproval = false

    init(workspace: AppWorkspace, storefront: any CapacityStorefront) {
        self.workspace = workspace; self.storefront = storefront
    }
    func identityChanged() {
        identity = nil; product = nil; pending = false; awaitingApproval = false; error = ""; activity = .idle
    }
    /// StoreKit is contacted only in the user-initiated capacity flow.
    func start() {
        storefront.observe { [weak self] transaction in
            guard let self, let identity = self.identity, self.matches(transaction, identity) else { return }
            do {
                try await self.confirm(transaction, identity: identity)
                if self.current(identity) {
                    self.pending = false; self.awaitingApproval = false; self.error = ""
                    if !self.activity.busy { self.activity = .idle }
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
            let identity = try await reconcile(synchronize: false)
            product = nil
            let loaded = try await storefront.product(PurchaseLedger.productID)
            guard current(identity) else { throw CancellationError() }
            guard loaded.id == PurchaseLedger.productID else { throw CoreFailure(message: "房源包信息不一致") }
            product = loaded
        } catch is CancellationError {} catch { product = nil; self.error = error.localizedDescription }
    }
    func purchase() async {
        guard !activity.busy, !pending, let product else { return }
        activity = .purchasing; error = ""
        defer { activity = pending ? .pending : .idle }
        do {
            let identity = try await reconcile(synchronize: false)
            let started = Date().timeIntervalSince1970
            switch try await storefront.purchase(product, accountToken: identity.accountToken) {
            case .cancelled: break
            case .pending:
                if current(identity) {
                    pending = true; awaitingApproval = true
                    _ = try? workspace?.store.call("reviewPurchasePending", ["value": .string("approval:\(started)")])
                }
            case .verified(let transaction):
                guard current(identity) else { return }
                pending = true
                _ = try? workspace?.store.call("reviewPurchasePending", ["value": .string(transaction.id)])
                try await confirm(transaction, identity: identity, requestReview: true)
                if current(identity) { pending = awaitingApproval }
            }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    func restore() async {
        guard !activity.busy else { return }
        activity = .restoring; error = ""
        defer { activity = pending ? .pending : .idle }
        do { _ = try await reconcile(synchronize: true) }
        catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    private func current(_ value: PurchaseIdentity) -> Bool { identity?.account == value.account }
    private func prepare(refresh: Bool = false) async throws -> PurchaseIdentity {
        let value = try await storefront.identity(refresh: refresh).validated()
        try Task.checkCancellation()
        if let old = identity, old.account != value.account {
            product = nil; pending = false; awaitingApproval = false
        }
        identity = value
        if let workspace, let cached = workspace.purchaseBalance, cached.account != value.account {
            // A different verified Apple account cannot inherit this device's prior capacity.
            try workspace.recordPurchases([], identity: value, snapshotStartedAt: workspace.purchaseRevision)
        }
        return value
    }
    @discardableResult private func reconcile(synchronize: Bool) async throws -> PurchaseIdentity {
        let value = try await prepare()
        let revision = workspace?.purchaseRevision ?? 0
        let transactions = try await storefront.transactions(synchronize: synchronize)
        guard current(value) else { throw CancellationError() }
        let confirmed = try await prepare(refresh: synchronize)
        guard current(confirmed), let workspace else { throw CancellationError() }
        try workspace.recordPurchases(transactions, identity: confirmed, snapshotStartedAt: revision)
        for transaction in transactions where matches(transaction, confirmed) {
            try await acknowledge(transaction, identity: confirmed)
        }
        pending = awaitingApproval
        return confirmed
    }
    private func matches(_ transaction: CapacityTransaction, _ identity: PurchaseIdentity) -> Bool {
        // Old purchases may have no appAccountToken; Apple's signed appTransactionID
        // establishes ownership without creating an app account or a new device identity.
        transaction.productID == PurchaseLedger.productID && transaction.environment == identity.environment
            && transaction.appTransactionID == identity.appTransactionID
    }
    private func confirm(_ transaction: CapacityTransaction, identity: PurchaseIdentity, requestReview: Bool = false) async throws {
        guard current(identity), matches(transaction, identity), let workspace else {
            throw CoreFailure(message: "请使用购买时的 App Store 账号恢复容量")
        }
        try workspace.recordPurchases([transaction], identity: identity)
        try await acknowledge(transaction, identity: identity, requestReview: requestReview)
    }
    private func acknowledge(_ transaction: CapacityTransaction, identity: PurchaseIdentity, requestReview: Bool = false) async throws {
        guard current(identity) else { throw CancellationError() }
        let pendingReview = workspace?.store.state["iosReview"]["pendingPurchase"].string ?? ""
        let approvalStarted = pendingReview.hasPrefix("approval:") ? Double(pendingReview.dropFirst(9)) : nil
        let approvedNewPurchase = approvalStarted.map { start in transaction.purchaseDate.map { $0.timeIntervalSince1970 >= start } ?? false } ?? false
        if workspace?.isActivePurchase(transaction.id) == true, transaction.revocationDate == nil, requestReview || pendingReview == transaction.id || approvedNewPurchase {
            _ = try? workspace?.store.call("reviewPurchaseConfirmed")
            awaitingApproval = false
        }
        let key = identity.account + ":" + transaction.id
        guard finished.insert(key).inserted else { return }
        // Both the ledger and capacity cache are already durable at this point.
        await storefront.finish(transaction)
    }
}
