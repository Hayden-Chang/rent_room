import Foundation
import Observation

@MainActor @Observable final class CapacityController {
    private(set) var activity = CapacityActivity.idle
    private(set) var error = ""
    private(set) var product: CapacityProduct?
    @ObservationIgnored private weak var workspace: AppWorkspace?
    @ObservationIgnored private let api: any CapacityServicing
    @ObservationIgnored private let storefront: any CapacityStorefront
    @ObservationIgnored private var context: CapacityContext?
    @ObservationIgnored private var verifications: [String: Task<CapacityConfirmation, Error>] = [:]
    @ObservationIgnored private var finished: Set<String> = []
    @ObservationIgnored private var pending = false
    @ObservationIgnored private var awaitingApproval = false
    init(workspace: AppWorkspace, api: any CapacityServicing, storefront: any CapacityStorefront) {
        self.workspace = workspace; self.api = api; self.storefront = storefront
    }
    func identityChanged() {
        context = nil; product = nil; pending = false; awaitingApproval = false; error = ""; activity = .idle
    }
    func start() {
        storefront.observe { [weak self] transaction in
            guard let self, let session = self.workspace?.session else { return }
            do {
                if self.context == nil { try await self.prepare(session, loadProduct: false) }
                guard self.matches(transaction) else { return }
                try await self.confirm(transaction, session: session, requestReview: self.awaitingApproval)
                if self.current(session) { self.pending = false; self.awaitingApproval = false; if !self.activity.busy { self.activity = .idle }; self.error = "" }
            } catch { if self.current(session) { self.pending = true; self.error = error.localizedDescription; if !self.activity.busy { self.activity = .pending } } }
        }
    }
    func load() async {
        guard !activity.busy, let session = workspace?.session else { return }
        activity = .loading; error = ""
        defer { if current(session) { activity = pending ? .pending : .idle } }
        do {
            try await prepare(session, loadProduct: true)
            for transaction in try await storefront.transactions(synchronize: false) {
                if matches(transaction) { pending = true; try await confirm(transaction, session: session); pending = awaitingApproval }
            }
        } catch { if current(session) { product = nil; self.error = error.localizedDescription } }
    }
    func purchase() async {
        guard !activity.busy, !pending, let session = workspace?.session, product != nil, let context, context.available else { return }
        activity = .purchasing; error = ""
        defer { if current(session) { activity = pending ? .pending : .idle } }
        do {
            guard session.expiresAt > Date() else { throw CoreFailure(message: "登录已过期，请重新登录后购买扩容") }
            try await prepare(session, loadProduct: true)
            guard let product = self.product, let context = self.context, context.available else { throw CoreFailure(message: "房源包暂未开放购买，请稍后再试") }
            switch try await storefront.purchase(product, accountToken: context.appAccountToken) {
            case .cancelled: break
            case .pending: if current(session) { pending = true; awaitingApproval = true }
            case .verified(let transaction):
                guard current(session) else { return }
                pending = true
                try await confirm(transaction, session: session, requestReview: true)
                if current(session) { pending = awaitingApproval }
            }
        } catch { if current(session) { self.error = error.localizedDescription } }
    }
    func restore() async {
        guard !activity.busy, let session = workspace?.session else { return }
        activity = .restoring; error = ""
        defer { if current(session) { activity = pending ? .pending : .idle } }
        do {
            try await prepare(session, loadProduct: false)
            for transaction in try await storefront.transactions(synchronize: true) {
                if matches(transaction) { pending = true; try await confirm(transaction, session: session); pending = awaitingApproval }
            }
            let balance = try await api.restore(token: session.token)
            try apply(balance, session: session)
            pending = awaitingApproval
        } catch { if current(session) { self.error = error.localizedDescription } }
    }
    private func current(_ session: LocalSession) -> Bool {
        workspace?.session?.account == session.account && workspace?.session?.token == session.token
    }
    private func prepare(_ session: LocalSession, loadProduct: Bool) async throws {
        let value = try await api.context(token: session.token)
        try apply(value.balance, session: session)
        context = value
        if loadProduct || !value.available { product = nil }
        if loadProduct, value.available, let id = value.productID {
            do {
                let loaded = try await storefront.product(id)
                guard current(session) else { throw CancellationError() }
                guard loaded.id == id else { throw CoreFailure(message: "房源包信息不一致") }
                product = loaded
            } catch {
                guard current(session) else { throw CancellationError() }
                self.error = error.localizedDescription
            }
        }
    }
    private func matches(_ transaction: CapacityTransaction) -> Bool {
        guard let context else { return false }
        return transaction.productID == context.productID && transaction.accountToken == context.appAccountToken && transaction.environment == context.balance.environment
    }
    private func confirm(_ transaction: CapacityTransaction, session: LocalSession, requestReview: Bool = false) async throws {
        guard current(session), matches(transaction) else { throw CoreFailure(message: "请登录购买时使用的账号后恢复容量") }
        let key = session.account + ":" + session.token + ":" + transaction.id
        let task: Task<CapacityConfirmation, Error>
        if let existing = verifications[key] { task = existing }
        else {
            task = Task { try await api.verify(transaction.id, token: session.token) }
            verifications[key] = task
        }
        defer { verifications[key] = nil }
        let value = try await task.value
        guard value.transactionID == transaction.id, ["verified", "revoked"].contains(value.status) else { throw CoreFailure(message: "购买记录暂时无法确认") }
        try apply(value.balance, session: session)
        if requestReview, value.status == "verified" {
            // Rating bookkeeping must never turn a completed purchase into an error.
            _ = try? workspace?.store.call("reviewPurchaseConfirmed")
        }
        guard !finished.contains(transaction.environment + ":" + transaction.id) else { return }
        finished.insert(transaction.environment + ":" + transaction.id)
        await storefront.finish(transaction)
    }
    private func apply(_ balance: CapacityBalance, session: LocalSession) throws {
        guard current(session), let workspace else { throw CancellationError() }
        guard balance.account == session.account, context == nil || balance.environment == context?.balance.environment else { throw CoreFailure(message: "容量记录与当前账号不一致") }
        try workspace.applyCapacity(balance)
    }
}
