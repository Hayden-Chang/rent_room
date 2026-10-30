import Foundation

/// A snapshot of verified Apple history, kept separately from house backups.
/// Revisions are local serialization markers, not server-provided entitlements.
struct PurchaseLedger: Codable {
    static let productID = "com.keeline.xunju.ios.capacity10"
    struct Entry: Codable { let transaction: CapacityTransaction; let revision: Int }
    let account: String
    let environment: String
    var revision: Int = 0
    var entries: [String: Entry] = [:]

    func balance(policy: CapacityPolicy) throws -> CapacityBalance {
        var packs = 0
        for entry in entries.values {
            let transaction = entry.transaction
            guard transaction.quantity > 0, transaction.quantity <= 10_000,
                  transaction.productID == Self.productID, transaction.environment == environment else {
                throw CoreFailure(message: "购买记录无效，请恢复容量")
            }
            if transaction.revocationDate == nil { packs += transaction.quantity }
        }
        return try CapacityBalance(account: account, environment: environment, packs: packs,
            limit: policy.freeLimit + packs * 10, revision: revision, capacity: policy).validated()
    }

    mutating func apply(_ transactions: [CapacityTransaction], identity: PurchaseIdentity,
                        snapshotStartedAt: Int?, minimumRevision: Int) throws {
        guard account == identity.account, environment == identity.environment else { throw CancellationError() }
        guard revision >= 0, minimumRevision >= 0, max(revision, minimumRevision) < Int.max else {
            throw CoreFailure(message: "购买记录版本无效，请恢复容量")
        }
        let nextRevision = max(revision, minimumRevision) + 1
        var updated: [String: Entry] = snapshotStartedAt == nil ? entries : [:]
        for transaction in transactions where transaction.productID == Self.productID {
            guard transaction.environment == environment, transaction.appTransactionID == identity.appTransactionID,
                  !transaction.id.isEmpty, transaction.quantity > 0, transaction.quantity <= 10_000 else {
                throw CoreFailure(message: "请使用购买时的 App Store 账号恢复容量")
            }
            if let old = updated[transaction.id] ?? entries[transaction.id],
               old.transaction.signedDate > transaction.signedDate ||
               (old.transaction.signedDate == transaction.signedDate && old.transaction.revocationDate != nil) {
                updated[transaction.id] = old
            } else {
                updated[transaction.id] = Entry(transaction: transaction, revision: nextRevision)
            }
        }
        if let started = snapshotStartedAt {
            // Transaction.updates may arrive while a full history is being enumerated.
            // Preserve those later writes even if the snapshot omitted the purchase.
            for (id, entry) in entries where entry.revision > started {
                if let snapshot = updated[id], snapshot.transaction.signedDate > entry.transaction.signedDate ||
                    (snapshot.transaction.signedDate == entry.transaction.signedDate && snapshot.transaction.revocationDate != nil) { continue }
                updated[id] = entry
            }
        }
        entries = updated; revision = nextRevision
    }
}

struct PurchaseLedgerStorage {
    let root: URL
    var url: URL { root.appending(path: "storekit-purchases.json") }
    func read() throws -> PurchaseLedger? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(PurchaseLedger.self, from: Data(contentsOf: url))
    }
    func write(_ ledger: PurchaseLedger) throws {
        try JSONEncoder().encode(ledger).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
