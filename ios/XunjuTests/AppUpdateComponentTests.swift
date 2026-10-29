import XCTest
@testable import Xunju

final class AppUpdateComponentTests: XCTestCase {
    private func bundle(_ info: [String: Any]) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(path: directory.path))
    }

    func testDisplayedVersionUsesInstalledMarketingVersionInsteadOfBuildNumber() throws {
        let source = try bundle(["CFBundleShortVersionString": "2.10.3", "CFBundleVersion": "2026103001"])
        XCTAssertEqual(InstalledAppVersion.display(in: source), "2.10.3")
    }

    func testMissingOrBlankVersionDoesNotInventAReleaseNumber() throws {
        let cases: [[String: Any]] = [[:], ["CFBundleVersion": "123"], ["CFBundleShortVersionString": " \n"]]
        for info in cases {
            XCTAssertEqual(InstalledAppVersion.display(in: try bundle(info)), "未知版本")
        }
    }

    #if DEBUG
    func testUpdateReviewRequiresExplicitRoute() {
        XCTAssertNil(ReviewSurface.parse(["--app-update"]))
        XCTAssertNil(ReviewSurface.parse(["--component-review"]))
        XCTAssertEqual(ReviewSurface.parse(["--component-review", "app-update"]), .appUpdate)
    }
    #endif
}
