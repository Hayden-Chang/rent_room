import XCTest
import UIKit
@testable import Xunju

@MainActor
final class OutsideInputTapTests: XCTestCase {
    func testBlankTitleAndButtonEndEditing() {
        let input = UITextField()
        for target in [UIView(), UILabel(), UIButton()] {
            XCTAssertTrue(OutsideInputTap.ObserverView.shouldDismiss(responder: input, target: target))
        }
    }
    func testInputContentAndAccessoryKeepEditing() {
        let input = UITextField(), content = UIView(), accessory = UIView(), key = UIButton()
        input.addSubview(content); accessory.addSubview(key); input.inputAccessoryView = accessory
        for target in [input, content, key] {
            XCTAssertFalse(OutsideInputTap.ObserverView.shouldDismiss(responder: input, target: target))
        }
    }
    func testAnotherEditableFieldKeepsNativeFocusTransfer() {
        let input = UITextField(), other = UITextField(), text = UITextView(), content = UIView()
        text.addSubview(content)
        for target in [other, text, content] {
            XCTAssertFalse(OutsideInputTap.ObserverView.shouldDismiss(responder: input, target: target))
        }
        other.isEnabled = false
        XCTAssertTrue(OutsideInputTap.ObserverView.shouldDismiss(responder: input, target: other))
    }
    func testMultilineInputAndNonTextResponder() {
        let text = UITextView(), child = UIView()
        text.addSubview(child)
        XCTAssertFalse(OutsideInputTap.ObserverView.shouldDismiss(responder: text, target: child))
        XCTAssertTrue(OutsideInputTap.ObserverView.shouldDismiss(responder: text, target: UIButton()))
        XCTAssertFalse(OutsideInputTap.ObserverView.shouldDismiss(responder: UIButton(), target: UIView()))
    }
}
