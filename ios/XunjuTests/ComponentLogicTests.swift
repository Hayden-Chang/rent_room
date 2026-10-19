import XCTest
@testable import Xunju

final class ComponentLogicTests: XCTestCase {
    func testPhoneRequiresElevenMainlandDigits() {
        XCTAssertTrue(PhoneLoginValidation.validPhone("13800138000"))
        for value in ["", "1380013800", "138001380001", "12800138000", "+8613800138000", "1380013800a", "13800138000\n"] {
            XCTAssertFalse(PhoneLoginValidation.validPhone(value), value)
        }
    }

    func testCodeRequiresSixASCIIDigits() {
        XCTAssertTrue(PhoneLoginValidation.validCode("012345"))
        for value in ["", "12345", "1234567", "１２３４５６", "12345a", "123456\n"] {
            XCTAssertFalse(PhoneLoginValidation.validCode(value), value)
        }
    }

    func testChoiceCanClearAndSwitchWithoutCouplingProblemFlag() {
        XCTAssertEqual(InspectionSelection.toggled(current: "正常", choice: "正常"), "")
        XCTAssertEqual(InspectionSelection.toggled(current: "正常", choice: "没有"), "没有")
        XCTAssertEqual(InspectionSelection.toggled(current: "", choice: "有问题"), "有问题")
    }

    #if DEBUG
    func testReviewHostRequiresExplicitKnownSurface() {
        XCTAssertNil(ReviewSurface.parse(["Xunju"]))
        XCTAssertNil(ReviewSurface.parse(["Xunju", "--component-review"]))
        XCTAssertNil(ReviewSurface.parse(["Xunju", "--component-review", "unknown"]))
        XCTAssertEqual(ReviewSurface.parse(["Xunju", "--component-review", "homes"]), .homes)
    }
    #endif
}
