import XCTest
@testable import Xunju

final class LocalAccountProfileTests: XCTestCase {
    private func directory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "profile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }
    func testProfilePersistsWithoutSharingAnotherAccountOrHouseState() throws {
        let a = LocalAccountProfile(directory: try directory())
        let b = LocalAccountProfile(directory: try directory())
        try Data("existing house state".utf8).write(to: a.directory.appending(path: "state.json"))
        try a.saveNickname("  小林  ")
        let png = Data([137, 80, 78, 71, 13, 10, 26, 10, 1])
        let first = try a.saveAvatar(png)
        let oldFile = try XCTUnwrap(a.avatarURL(first))
        let next = try a.saveAvatar(png + Data([2]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        let restored = LocalAccountProfile(directory: a.directory)
        XCTAssertEqual(restored.read(), next)
        XCTAssertEqual(restored.read().nickname, "小林")
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(restored.avatarURL(next))), png + Data([2]))
        XCTAssertEqual(b.read(), LocalAccountProfile.Value())
        XCTAssertEqual(try String(contentsOf: a.directory.appending(path: "state.json"), encoding: .utf8), "existing house state")
    }
    func testInvalidProfileAndFailedAvatarWriteNeverEscapeOrLeaveNewFiles() throws {
        let profile = LocalAccountProfile(directory: try directory())
        try profile.saveNickname("原昵称")
        XCTAssertThrowsError(try profile.saveNickname("  "))
        XCTAssertThrowsError(try profile.saveNickname(String(repeating: "字", count: 33)))
        XCTAssertThrowsError(try profile.saveAvatar(Data("not an image".utf8)))
        XCTAssertEqual(profile.read().nickname, "原昵称")
        XCTAssertNil(profile.avatarURL(.init(nickname: "", avatarFile: "../other.png")))
        let blocked = LocalAccountProfile(directory: try directory())
        try FileManager.default.createDirectory(at: blocked.directory.appending(path: "profile.json"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try blocked.saveAvatar(Data([137, 80, 78, 71, 13, 10, 26, 10])))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: blocked.directory.path), ["profile.json"])
    }
}
