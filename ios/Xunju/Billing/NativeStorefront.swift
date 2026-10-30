import Foundation
import StoreKit

struct CapacityProduct: Sendable { let id: String; let displayPrice: String }
struct CapacityTransaction: Codable, Sendable, Equatable {
    let id: String; let productID: String; let accountToken: UUID?; let environment: String
    var appTransactionID: String = ""
    var purchaseDate: Date? = nil
    var quantity: Int = 1
    var revocationDate: Date? = nil
    var signedDate: Date = .distantPast
}
enum CapacityPurchaseResult: Sendable { case cancelled, pending, verified(CapacityTransaction) }
@MainActor protocol CapacityStorefront: AnyObject {
    func identity(refresh: Bool) async throws -> PurchaseIdentity
    func stopObserving()
    func product(_ id: String) async throws -> CapacityProduct
    func purchase(_ product: CapacityProduct, accountToken: UUID) async throws -> CapacityPurchaseResult
    func transactions(synchronize: Bool) async throws -> [CapacityTransaction]
    func finish(_ transaction: CapacityTransaction) async
    func observe(_ receive: @escaping @MainActor (CapacityTransaction) async -> Void)
}

/// Only StoreKit-verified transactions cross this boundary into the local ledger.
@MainActor final class NativeStorefront: CapacityStorefront {
    private var products: [String: Product] = [:]
    private var verified: [String: StoreKit.Transaction] = [:]
    private var observer: Task<Void, Never>?
    deinit { observer?.cancel() }
    func stopObserving() { observer?.cancel(); observer = nil }
    func identity(refresh: Bool) async throws -> PurchaseIdentity {
        var result: VerificationResult<AppTransaction>
        if refresh { result = try await AppTransaction.refresh() }
        else { result = try await AppTransaction.shared }
        if case .verified(let value) = result, value.appTransactionID.isEmpty, !refresh {
            result = try await AppTransaction.refresh()
        }
        guard case .verified(let value) = result else {
            throw CoreFailure(message: "App Store 购买身份未通过校验，请稍后恢复容量")
        }
        guard value.bundleID == Bundle.main.bundleIdentifier else {
            throw CoreFailure(message: "App Store 购买身份与当前应用不一致")
        }
        return try PurchaseIdentity(appTransactionID: value.appTransactionID, bundleID: value.bundleID,
            environment: value.environment.rawValue, signedAppTransaction: result.jwsRepresentation).validated()
    }
    func product(_ id: String) async throws -> CapacityProduct {
        guard let product = try await Product.products(for: [id]).first(where: { $0.id == id && $0.type == .consumable }) else {
            throw CoreFailure(message: "房源包暂未开放购买，请稍后再试")
        }
        products[id] = product
        return CapacityProduct(id: id, displayPrice: product.displayPrice)
    }
    func purchase(_ product: CapacityProduct, accountToken: UUID) async throws -> CapacityPurchaseResult {
        guard let native = products[product.id] else { throw CoreFailure(message: "请重新加载房源包") }
        switch try await native.purchase(options: [.appAccountToken(accountToken)]) {
        case .userCancelled: return .cancelled
        case .pending: return .pending
        case .success(let result): return .verified(try remember(result))
        @unknown default: throw CoreFailure(message: "购买状态暂时无法确认，请稍后恢复容量")
        }
    }
    func transactions(synchronize: Bool) async throws -> [CapacityTransaction] {
        if synchronize { try await AppStore.sync() }
        var result: [String: CapacityTransaction] = [:]
        // iOS 18 + SKIncludeConsumableInAppPurchaseHistory includes finished purchases.
        // Reject the entire snapshot on failed verification; never erase cached capacity
        // using a partially verified history.
        for await value in StoreKit.Transaction.all {
            let transaction = try remember(value); result[transaction.id] = transaction
        }
        return Array(result.values)
    }
    func finish(_ transaction: CapacityTransaction) async {
        guard let value = verified.removeValue(forKey: transaction.id) else { return }
        await value.finish()
    }
    func observe(_ receive: @escaping @MainActor (CapacityTransaction) async -> Void) {
        guard observer == nil else { return }
        observer = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                // Unverified updates remain unfinished and cannot grant capacity.
                if let transaction = try? self.remember(result) { await receive(transaction) }
            }
        }
    }
    private func remember(_ result: VerificationResult<StoreKit.Transaction>) throws -> CapacityTransaction {
        guard case .verified(let value) = result else { throw CoreFailure(message: "购买凭证未通过校验，请稍后恢复容量") }
        let record = CapacityTransaction(id: String(value.id), productID: value.productID, accountToken: value.appAccountToken, environment: value.environment.rawValue, appTransactionID: value.appTransactionID, purchaseDate: value.purchaseDate, quantity: value.purchasedQuantity, revocationDate: value.revocationDate, signedDate: value.signedDate)
        verified[record.id] = value
        return record
    }
}
