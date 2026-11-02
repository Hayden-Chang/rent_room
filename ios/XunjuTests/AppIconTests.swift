import XCTest
import UIKit

@MainActor
final class AppIconTests: XCTestCase {
    func testBuiltAppContainsPrimaryIconMetadataAndImages() throws {
        // Bundle's key lookup applies device qualifiers; inspect the packaged plist
        // directly so an iPhone test can also verify the iPad icon declaration.
        let plistURL = try XCTUnwrap(Bundle.main.url(forResource: "Info", withExtension: "plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any])
        let resources = try FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            let icons = try XCTUnwrap(info[key] as? [String: Any], "Missing \(key) in the installed app")
            let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
            XCTAssertEqual(primary["CFBundleIconName"] as? String, "AppIcon")
            let files = try XCTUnwrap(primary["CFBundleIconFiles"] as? [String])
            XCTAssertFalse(files.isEmpty)
            for name in files {
                let matches = resources.filter { $0.lastPathComponent.hasPrefix(name) && $0.pathExtension == "png" }
                XCTAssertFalse(matches.isEmpty, "Missing compiled icon \(name)")
                for url in matches {
                    let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
                    XCTAssertGreaterThan(image.width, 0)
                    XCTAssertEqual(image.width, image.height)
                }
            }
        }
    }
}
