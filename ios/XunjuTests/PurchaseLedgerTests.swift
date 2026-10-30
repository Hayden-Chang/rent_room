import XCTest
@testable import Xunju

final class PurchaseLedgerTests: XCTestCase {
    private let identity = CapacityTestStorefront.testIdentity
    private func transaction(_ id: String = "1", quantity: Int = 1, revoked: Bool = false, signed: Double = 1) -> CapacityTransaction {
        CapacityTransaction(id: id, productID: PurchaseLedger.productID, accountToken: nil,
            environment: "Sandbox", appTransactionID: identity.appTransactionID, quantity: quantity,
            revocationDate: revoked ? Date(timeIntervalSince1970: signed) : nil, signedDate: Date(timeIntervalSince1970: signed))
    }
    func testQuantitiesDeduplicateAndNewestRefundWinsRegardlessOfOrder() throws {
        for history in [[transaction(quantity: 2), transaction(quantity: 2, revoked: true, signed: 2)],
                        [transaction(quantity: 2, revoked: true, signed: 2), transaction(quantity: 2)]] {
            var ledger = PurchaseLedger(account: identity.account, environment: "Sandbox")
            try ledger.apply(history + [transaction("2", quantity: 3)], identity: identity, snapshotStartedAt: 0, minimumRevision: 0)
            XCTAssertEqual(try ledger.balance(policy: .initial).packs, 3)
            try ledger.apply([transaction(quantity: 2)], identity: identity, snapshotStartedAt: nil, minimumRevision: 0)
            XCTAssertEqual(try ledger.balance(policy: .initial).packs, 3)
        }
    }
    func testNewerRefundInSnapshotCannotBeOverwrittenByConcurrentOlderUpdate() throws {
        var ledger = PurchaseLedger(account: identity.account, environment: "Sandbox")
        let started = ledger.revision
        try ledger.apply([transaction()], identity: identity, snapshotStartedAt: nil, minimumRevision: 0)
        try ledger.apply([transaction(revoked: true, signed: 2)], identity: identity, snapshotStartedAt: started, minimumRevision: 0)
        XCTAssertEqual(try ledger.balance(policy: .initial).packs, 0)
    }
    func testForeignInvalidAndOtherProductHistoryCannotGrantCapacity() throws {
        var ledger = PurchaseLedger(account: identity.account, environment: "Sandbox")
        for value in [transaction(quantity: 0), transaction(quantity: -1), transaction(quantity: 10001)] {
            XCTAssertThrowsError(try ledger.apply([value], identity: identity, snapshotStartedAt: 0, minimumRevision: 0))
        }
        let foreign = CapacityTransaction(id: "1", productID: PurchaseLedger.productID, accountToken: nil, environment: "Production", appTransactionID: identity.appTransactionID)
        XCTAssertThrowsError(try ledger.apply([foreign], identity: identity, snapshotStartedAt: 0, minimumRevision: 0))
        let other = CapacityTransaction(id: "2", productID: "unrelated", accountToken: nil, environment: "Sandbox")
        try ledger.apply([other], identity: identity, snapshotStartedAt: 0, minimumRevision: 0)
        XCTAssertEqual(try ledger.balance(policy: .initial).packs, 0)
    }
    func testCompleteHistoryReplacesMissingEntriesButRetainsConcurrentUpdate() throws {
        var ledger = PurchaseLedger(account: identity.account, environment: "Sandbox")
        try ledger.apply([transaction()], identity: identity, snapshotStartedAt: 0, minimumRevision: 0)
        let started = ledger.revision
        try ledger.apply([transaction("2")], identity: identity, snapshotStartedAt: nil, minimumRevision: 0)
        try ledger.apply([], identity: identity, snapshotStartedAt: started, minimumRevision: 0)
        XCTAssertEqual(Set(ledger.entries.keys), ["2"])
        try ledger.apply([], identity: identity, snapshotStartedAt: ledger.revision, minimumRevision: 0)
        XCTAssertEqual(try ledger.balance(policy: .initial).packs, 0)
    }
}
