import XCTest
import UIKit
@testable import Xunju

@MainActor
final class AppIconTests: XCTestCase {
    func testBuiltAppSupportsOnlyIPhone() throws {
        let families = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int])
        XCTAssertEqual(families, [1], "The packaged app must target iPhone only")
    }

    func testEnglishDisplayNameUsesRentVisit() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: "en.lproj"))
        let values = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        XCTAssertEqual(values["CFBundleDisplayName"], "RentVisit")
    }

    func testChineseDisplayNameUsesKanfangDazi() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: "zh-Hans.lproj"))
        let values = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        XCTAssertEqual(values["CFBundleDisplayName"], "看房搭子")
        XCTAssertEqual(values["CFBundleDisplayName"], Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
        XCTAssertEqual(AppCopy.text("看房搭子", language: .english), "RentVisit")
    }

    func testBuiltAppContainsPrimaryIconMetadataAndImages() throws {
        // Inspect the packaged iPhone icon declaration and compiled images.
        let plistURL = try XCTUnwrap(Bundle.main.url(forResource: "Info", withExtension: "plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any])
        let resources = try FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)
        for key in ["CFBundleIcons"] {
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
