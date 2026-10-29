import XCTest
@testable import Xunju

final class IdentityScopeTests: XCTestCase {
    private let accountA = String(repeating: "a", count: 64)
    private let accountB = String(repeating: "b", count: 64)

    @MainActor
    private func scopes() throws -> LocalIdentityScopes {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("xunju-scope-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try LocalIdentityScopes(root: root)
    }

    @MainActor
    func testGuestClaimIsIdempotentAndLogoutStartsFreshGuest() throws {
        let scopes = try scopes()
        let source = try NativeStore(directory: scopes.guestDirectory())
        let id = try source.add("游客房源")
        try source.answer(id, field: "f1_6", value: .string("2800"))
        let target = try scopes.claim(account: accountA, from: source)
        XCTAssertEqual(target.houses.map(\.name), ["游客房源"])
        XCTAssertEqual(target.houses.first?.rent, "2800")
        let again = try scopes.claim(account: accountA, from: source)
        XCTAssertEqual(again.houses.count, 1)
        XCTAssertEqual(source.houses.count, 1, "Originals remain recoverable")
        XCTAssertNotEqual(try scopes.guestDirectory(), source.records.directory)
        let fresh = try NativeStore(directory: scopes.guestDirectory())
        XCTAssertTrue(fresh.houses.isEmpty)
        XCTAssertThrowsError(try scopes.claim(account: accountB, from: source))
        XCTAssertTrue(try NativeStore(directory: scopes.accountDirectory(accountB)).houses.isEmpty)
    }

    @MainActor
    func testClaimPreservesOverCapacityRecordsWithoutGrantingCapacity() throws {
        let scopes = try scopes()
        let account = try NativeStore(directory: scopes.accountDirectory(accountA), freeLimit: 2)
        _ = try account.add("账号一")
        _ = try account.add("账号二")
        try account.call("settings", ["property": .string("workplace"), "value": .string("账号公司")])
        let source = try NativeStore(directory: scopes.guestDirectory(), freeLimit: 2)
        _ = try source.add("游客一")
        _ = try source.add("游客二")
        let merged = try scopes.claim(account: accountA, from: source)
        XCTAssertEqual(merged.houses.count, 4)
        XCTAssertEqual(merged.capacity.used, 4)
        XCTAssertEqual(merged.capacity.limit, 1)
        XCTAssertThrowsError(try merged.add("禁止超额新增"))
        XCTAssertEqual(merged.state["settings"]["workplace"].string, "账号公司")
    }

    @MainActor
    func testFirstClaimKeepsGuestSettingsAndCopiesMediaWithoutChangingOriginal() throws {
        let scopes = try scopes()
        let source = try NativeStore(directory: scopes.guestDirectory())
        let id = try source.add("带照片房源")
        try source.call("settings", ["property": .string("workplace"), "value": .string("游客公司")])
        let original = source.records.directory.appending(path: "media/photo1.jpg")
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1, 2, 3, 4]).write(to: original)
        try source.call("addMedia", ["id": .string(id), "value": .object([
            "id": .string("m1"), "type": .string("image"), "path": .string("media/photo1.jpg"), "fieldId": .string("f1_6"), "caption": .string("原图备注")])])
        let target = try scopes.claim(account: accountA, from: source)
        let media = try XCTUnwrap(target.house(id)["media"].array.first)
        XCTAssertNotEqual(media["path"].string, "media/photo1.jpg")
        let copied = try scopes.mediaURL(media["path"].string, in: target.records.directory)
        XCTAssertEqual(try Data(contentsOf: copied), Data([1, 2, 3, 4]))
        XCTAssertEqual(try Data(contentsOf: original), Data([1, 2, 3, 4]))
        XCTAssertEqual(media["caption"].string, "原图备注")
        XCTAssertEqual(target.state["settings"]["workplace"].string, "游客公司")
        XCTAssertEqual(source.house(id)["media"].array.first?["path"].string, "media/photo1.jpg")
    }

    @MainActor
    func testFailedMediaClaimRetainsJournalAndCanResumeOnce() throws {
        let scopes = try scopes()
        let source = try NativeStore(directory: scopes.guestDirectory())
        let id = try source.add("恢复房源")
        try source.call("addMedia", ["id": .string(id), "value": .object([
            "id": .string("m1"), "type": .string("image"), "path": .string("media/missing.jpg"), "fieldId": .string("")])])
        XCTAssertThrowsError(try scopes.claim(account: accountA, from: source))
        let directory = try scopes.accountDirectory(accountA)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("guest-claim.json").path))
        XCTAssertTrue(try NativeStore(directory: directory).houses.isEmpty)
        let file = source.records.directory.appending(path: "media/missing.jpg")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([5, 6, 7]).write(to: file)
        let recovered = try scopes.claim(account: accountA, from: nil)
        XCTAssertEqual(recovered.houses.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("guest-claim.json").path))
        XCTAssertEqual(try scopes.claim(account: accountA, from: source).houses.count, 1)
    }

    @MainActor
    func testDuplicateHouseIDsReceiveNewIDWithoutOverwritingAccount() throws {
        let scopes = try scopes()
        let account = try NativeStore(directory: scopes.accountDirectory(accountA))
        let id = try account.add("账号原房源")
        let source = try NativeStore(directory: scopes.guestDirectory())
        let incoming = account.house(id).setting("name", to: .string("游客同编号房源"))
        try source.call("import", ["houses": .array([incoming]), "replaceIds": .array([])])
        let merged = try scopes.claim(account: accountA, from: source)
        XCTAssertEqual(Set(merged.houses.map(\.id)).count, 2)
        XCTAssertEqual(merged.house(id)["name"].string, "账号原房源")
        XCTAssertEqual(Set(merged.houses.map(\.name)), ["账号原房源", "游客同编号房源"])
    }

    @MainActor
    func testMalformedScopePointerAndMediaPathsNeverEscapeRoot() throws {
        let scopes = try scopes()
        for id in ["../outside", "a", String(repeating: "a", count: 64) + "\n"] {
            XCTAssertThrowsError(try scopes.accountDirectory(id))
        }
        for path in ["../state.json", "/tmp/other.jpg", "media/../../other.jpg", "media/photo.jpg/child"] {
            XCTAssertThrowsError(try scopes.mediaURL(path, in: scopes.root))
        }
        let pointer = scopes.root.appendingPathComponent("guest-current.json")
        try Data("{\"id\":\"../outside\"}".utf8).write(to: pointer)
        XCTAssertThrowsError(try scopes.guestDirectory())
        XCTAssertEqual(try String(contentsOf: pointer, encoding: .utf8), "{\"id\":\"../outside\"}")
    }
}
