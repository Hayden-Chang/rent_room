import XCTest
import UIKit

@MainActor
final class AppIconTests: XCTestCase {
    func testBuiltAppContainsPrimaryIconMetadataAndImages() throws {
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            let icons = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? [String: Any], "Missing \(key) in the installed app")
            let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
            XCTAssertEqual(primary["CFBundleIconName"] as? String, "AppIcon")
            let files = try XCTUnwrap(primary["CFBundleIconFiles"] as? [String])
            XCTAssertFalse(files.isEmpty)
            for name in files {
                let image = try XCTUnwrap(UIImage(named: name, in: .main, compatibleWith: nil), "Missing compiled icon \(name)")
                XCTAssertGreaterThan(image.size.width, 0)
                XCTAssertEqual(image.size.width, image.size.height)
            }
        }
    }
}
