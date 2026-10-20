import XCTest
@testable import Xunju

@MainActor final class BusinessIntegrationTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "business-unit-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    private func receipt(_ account: String = String(repeating: "a", count: 64)) -> LoginReceipt {
        LoginReceipt(account: account, token: String(repeating: "t", count: 48), provider: "phone", expiresIn: 7200, packs: 0, limit: 2)
    }
    func testGuestWorkspaceRelaunchRetainsRealRecordsAndScopes() throws {
        let root = try root(), keychain = VolatileSessionStorage(), workspace = try AppWorkspace(root: root, keychain: keychain)
        let id = try workspace.store.add("本机新房源")
        try workspace.store.answer(id, field: "f1_1", value: .string("朝阳路18号"))
        try workspace.store.answer(id, field: "f1_6", value: .string("0"))
        let restored = try AppWorkspace(root: root, keychain: keychain)
        XCTAssertEqual(restored.store.houses.first?.rent, "0")
        XCTAssertEqual(restored.store.houses.first?.address, "朝阳路18号")
        XCTAssertEqual(restored.store.records.directory, workspace.store.records.directory)
    }
    func testChoiceCommandRetainsMultipleValuesAndOtherDetailAcrossRelaunch() throws {
        let store = try NativeStore(directory: root()), id = try store.add("多选房源")
        func choose(_ field: String, _ value: String) throws { try store.call("choose", ["id": .string(id), "field": .string(field), "value": .string(value)]) }
        try choose("f83_2", "联通"); try choose("f83_2", "移动")
        XCTAssertEqual(store.house(id)["answers"]["f83_2"]["value"].array.map(\.string), ["联通", "移动"])
        try choose("f83_2", "联通")
        XCTAssertEqual(store.house(id)["answers"]["f83_2"]["value"].array.map(\.string), ["移动"])
        try choose("f1_5", "其他")
        try store.answer(id, field: "f1_5", property: "otherText", value: .string("双面采光"))
        try choose("f1_5", "南"); try choose("f1_5", "其他")
        XCTAssertEqual(store.house(id)["answers"]["f1_5"]["otherText"].string, "双面采光")
        XCTAssertThrowsError(try choose("f1_5", "invalid"))
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"]["f83_2"]["value"].array.map(\.string), ["移动"])
    }
    func testVerifiedLoginClaimLogoutAndSameAccountResumeKeepGuestPrivate() throws {
        let root = try root(), keychain = VolatileSessionStorage(), workspace = try AppWorkspace(root: root, keychain: keychain)
        let id = try workspace.store.add("登录前记录")
        try workspace.accept(receipt())
        XCTAssertEqual(workspace.store.houses.map(\.id), [id])
        XCTAssertEqual(workspace.session?.provider, "phone")
        let resumed = try AppWorkspace(root: root, keychain: keychain)
        XCTAssertEqual(resumed.store.houses.map(\.id), [id])
        try resumed.logout()
        XCTAssertTrue(resumed.store.houses.isEmpty)
        let guestID = try resumed.store.add("另一批游客记录")
        try resumed.accept(receipt(String(repeating: "b", count: 64)))
        XCTAssertEqual(resumed.store.houses.map(\.id), [guestID])
        try resumed.logout()
        try resumed.accept(receipt())
        XCTAssertEqual(resumed.store.houses.map(\.id), [id])
    }
    func testKeychainFailureDoesNotClaimGuestOrChangeCurrentStore() throws {
        final class BrokenKeychain: SessionStorage {
            func read() -> LocalSession? { nil }
            func write(_ session: LocalSession) throws { throw CoreFailure(message: "模拟 Keychain 保存失败") }
            func remove() {}
        }
        let root = try root(), workspace = try AppWorkspace(root: root, keychain: BrokenKeychain())
        let id = try workspace.store.add("受保护的游客记录"), directory = workspace.store.records.directory
        XCTAssertThrowsError(try workspace.accept(receipt()))
        XCTAssertNil(workspace.session)
        XCTAssertEqual(try workspace.scopes.guestDirectory(), directory)
        XCTAssertEqual(try AppWorkspace(root: root, keychain: VolatileSessionStorage()).store.houses.map(\.id), [id])
    }
    func testImportCopyUsesNewIDKeepsOriginalAndFailsAtomicallyAtCapacity() async throws {
        let store = try NativeStore(directory: root()), id = try store.add("原有"), transfer = BackupTransfers()
        let zip = store.records.directory.appending(path: "copy.zip")
        try await transfer.export(ids: [id], store: store, to: zip)
        let preview = try await transfer.preview(zip, store: store)
        try await transfer.importSelected(zip, preview: preview, selectedIDs: [id], replacing: [], copying: [id], store: store, isCurrent: { true })
        XCTAssertEqual(store.houses.count, 2)
        XCTAssertNotEqual(store.houses[0].id, store.houses[1].id)
        let state = store.state
        do { try await transfer.importSelected(zip, preview: preview, selectedIDs: [id], replacing: [], copying: [id], store: store, isCurrent: { true }); XCTFail("capacity must reject third active house") } catch {}
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).houses.count, 2)
    }
    func testCorruptSignedInAccountStillOpensRecoveryAndRetainsOriginalFile() throws {
        let root = try root(), keychain = VolatileSessionStorage(), workspace = try AppWorkspace(root: root, keychain: keychain)
        let id = try workspace.store.add("账号记录")
        try workspace.store.answer(id, field: "f1_6", value: .string("2800"))
        try workspace.accept(receipt())
        try workspace.store.answer(id, field: "f1_6", value: .string("3000"))
        let file = workspace.store.records.directory.appending(path: "state.json")
        try Data("broken-account-file".utf8).write(to: file)
        let reopened = try AppWorkspace(root: root, keychain: keychain)
        XCTAssertTrue(reopened.store.status.blocked)
        XCTAssertNotNil(reopened.session)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "broken-account-file")
        // The same recovery command used by the on-screen banner must remain reachable.
        try reopened.store.call("recover")
        XCTAssertEqual(reopened.store.houses.map(\.id), [id])
        XCTAssertEqual(reopened.store.houses.first?.rent, "2800")
    }
    func testOnlyExplicitUUIDArgumentEnablesIsolatedBusinessDirectory() throws {
        let id = UUID().uuidString
        XCTAssertTrue(try AppWorkspace.dataRoot(arguments: ["app", "--business-test", id]).path.hasSuffix("XunjuBusinessTests/" + id))
        XCTAssertFalse(try AppWorkspace.dataRoot(arguments: ["app", "--business-test", "../../user-data"]).path.contains("XunjuBusinessTests"))
        XCTAssertFalse(try AppWorkspace.dataRoot(arguments: ["app", "--business-test"]).path.contains("XunjuBusinessTests"))
    }
}
