import XCTest
import UIKit

@MainActor
final class LaunchScreenTests: XCTestCase {
    func testBuiltAppCanLoadCenteredLaunchScreen() throws {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "UILaunchStoryboardName") as? String, "LaunchScreen")
        let controller = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: bundle).instantiateInitialViewController())
        controller.loadViewIfNeeded()
        let view = try XCTUnwrap(controller.view)
        let logo = try XCTUnwrap(view.subviews.compactMap { $0 as? UIImageView }.first)
        XCTAssertNotNil(logo.image)
        XCTAssertEqual(logo.image?.size, CGSize(width: 112, height: 112))
        XCTAssertEqual(view.subviews.count, 1, "System launch contains only the approved logo")
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            view.frame = CGRect(origin: .zero, size: size)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            XCTAssertEqual(logo.frame.width, 112, accuracy: 0.5)
            XCTAssertEqual(logo.frame.height, 112, accuracy: 0.5)
            XCTAssertEqual(logo.frame.midX, view.bounds.midX, accuracy: 0.5)
            XCTAssertEqual(logo.frame.midY, view.bounds.midY, accuracy: 0.5)
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(view.backgroundColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha) == true)
        XCTAssertEqual(red, 245.0 / 255, accuracy: 0.001)
        XCTAssertEqual(green, 247.0 / 255, accuracy: 0.001)
        XCTAssertEqual(blue, 251.0 / 255, accuracy: 0.001)
        XCTAssertEqual(alpha, 1)
    }
}
