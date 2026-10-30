import XCTest
@testable import Xunju

private actor OfflineCallCounter: CapacityPolicyServicing, MapTransport {
    var count = 0
    func fetch() -> CapacityPolicy? { count += 1; return nil }
    func request(_ options: String) async throws -> String { count += 1; throw CoreFailure(message: "offline") }
}
@MainActor final class OfflineWorkspaceTests: XCTestCase {
    private func root() -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "offline-tests-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func testGuestRecordsAndAnswersSurviveOfflineRestartWithoutServiceCalls() async throws {
        let root = root(), counter = OfflineCallCounter(), storefront = CapacityTestStorefront(), api = CapacityTestAPI()
        let first = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), mapTransport: counter, capacityAPI: api, storefront: storefront, policyAPI: counter)
        let id = try first.store.add("离线记录")
        try first.store.answer(id, field: "f1_6", value: .string("1800")); first.save()
        let second = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), mapTransport: counter, capacityAPI: api, storefront: storefront, policyAPI: counter)
        XCTAssertEqual(first.store.records.directory, second.store.records.directory)
        XCTAssertEqual(second.store.house(id)["answers"]["f1_6"]["value"].string, "1800")
        XCTAssertNil(second.session); XCTAssertNil(storefront.receive)
        let calls = await counter.count; XCTAssertEqual(calls, 0)
        XCTAssertNil(second.billing.product); XCTAssertEqual(storefront.purchases, 0)
    }
    func testExpiredLegacyAccountKeepsOriginalMediaDirectoryAndNeedsNoKeychainAfterMigration() throws {
        let root = root(), keychain = VolatileSessionStorage(), scopes = try LocalIdentityScopes(root: root)
        let receipt = LoginReceipt(account: String(repeating: "a", count: 64), token: String(repeating: "t", count: 40), provider: "apple", expiresIn: 1, packs: 1, limit: 12)
        let legacy = try LocalSession(receipt: receipt, now: Date(timeIntervalSince1970: 0)); keychain.write(legacy)
        let directory = try scopes.accountDirectory(legacy.account), old = try NativeStore(directory: directory, packs: 1)
        let id = try old.add("原账号房源")
        let image = directory.appending(path: "media/photo.jpg")
        try FileManager.default.createDirectory(at: image.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1,2,3]).write(to: image)
        try old.call("addMedia", ["id": .string(id), "value": .object(["id": .string("photo"), "type": .string("image"), "path": .string("media/photo.jpg"), "fieldId": .string("f1_6")])])
        let migrated = try AppWorkspace(root: root, keychain: keychain)
        XCTAssertEqual(migrated.store.records.directory, directory)
        XCTAssertEqual(migrated.store.houses.first?.name, "原账号房源")
        XCTAssertEqual(try Data(contentsOf: image), Data([1,2,3]))
        keychain.remove()
        let reopened = try AppWorkspace(root: root, keychain: keychain)
        XCTAssertEqual(reopened.store.records.directory, directory)
        XCTAssertEqual(reopened.store.capacity.limit, 11)
        XCTAssertEqual(reopened.store.house(id)["media"].array.first?["path"].string, "media/photo.jpg")
    }
    func testMalformedOfflinePointerNeverFallsBackToAnEmptyStore() throws {
        let root = root(), first = try AppWorkspace(root: root, keychain: VolatileSessionStorage())
        _ = try first.store.add("不得丢失")
        let file = root.appending(path: "local-current.json")
        try JSONEncoder().encode("../outside").write(to: file)
        XCTAssertThrowsError(try AppWorkspace(root: root, keychain: VolatileSessionStorage()))
        XCTAssertEqual(try NativeStore(directory: first.store.records.directory).houses.first?.name, "不得丢失")
    }
    func testSavedAddressAndCoordinatesDoNotQueryUntilExplicitMapAction() async throws {
        let counter = OfflineCallCounter()
        let store = try NativeStore(directory: root(), network: counter)
        for location: JSONValue in [.null, .object(["latitude": .number(31.23), "longitude": .number(121.47)])] {
            let search = PlaceSearch(store: store, location: location, mapKey: "fixture", validScope: { true })
            search.start(address: "已保存的地址")
            XCTAssertFalse(search.busy); XCTAssertTrue(search.choices.isEmpty)
            let before = await counter.count
            await search.submit()?.value
            let after = await counter.count
            XCTAssertEqual(after, before + 1, "Only explicit submission may contact the map service")
            search.cancel()
        }
    }
    func testChangingApplePurchaseIdentityNeverSwitchesHouseDirectory() throws {
        let root = root(), workspace = try AppWorkspace(root: root, keychain: VolatileSessionStorage())
        let store = workspace.store, id = try store.add("一直在本机")
        for appID in ["9001", "9002"] {
            let identity = PurchaseIdentity(appTransactionID: appID, bundleID: "test.xunju", environment: "Sandbox", signedAppTransaction: "proof")
            try workspace.applyPurchaseCapacity(CapacityBalance(account: identity.account, environment: "Sandbox", packs: appID == "9001" ? 1 : 0, limit: appID == "9001" ? 11 : 1, revision: 1, capacity: .initial), identity: identity)
            XCTAssertTrue(workspace.store === store); XCTAssertEqual(store.house(id)["name"].string, "一直在本机")
        }
        let reopened = try AppWorkspace(root: root, keychain: VolatileSessionStorage())
        XCTAssertEqual(reopened.store.records.directory, store.records.directory); XCTAssertEqual(reopened.store.capacity.limit, 1)
        XCTAssertEqual(reopened.store.houses.count, 1)
    }
}
