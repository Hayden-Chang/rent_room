import XCTest
import UIKit
@testable import Xunju

final class InspectionSetupTests: XCTestCase {
    func testDisableRestoreAndLastCategoryProtection() {
        var draft = InspectionTemplateDraft(order: ["房源基本信息", "周边与小区"])
        XCTAssertNil(draft.toggle("房源基本信息"))
        XCTAssertEqual(draft.disabled, ["房源基本信息"])
        XCTAssertEqual(draft.toggle("周边与小区"), "至少保留一个检查大项。")
        XCTAssertEqual(draft.disabled, ["房源基本信息"])
        XCTAssertNil(draft.toggle("房源基本信息"))
        XCTAssertTrue(draft.disabled.isEmpty)
    }

    func testReorderBothDirectionsPreservesDisabledCategories() {
        var draft = InspectionTemplateDraft(order: ["房源基本信息", "周边与小区", "家电"], disabled: ["周边与小区"])
        draft.move("房源基本信息", to: "家电")
        XCTAssertEqual(draft.order, ["周边与小区", "家电", "房源基本信息"])
        draft.move("房源基本信息", to: "周边与小区")
        XCTAssertEqual(draft.order, ["房源基本信息", "周边与小区", "家电"])
        XCTAssertEqual(draft.disabled, ["周边与小区"])
    }

    func testInvalidDropAndToggleCannotAlterDraft() {
        var draft = InspectionTemplateDraft(order: ["家电", "卫生间"])
        let original = draft
        draft.move("外部拖入文字", to: "家电")
        draft.move("家电", to: "未知分类")
        draft.move("家电", to: "家电")
        XCTAssertEqual(draft.toggle("未知分类"), "清单排序数据无效")
        XCTAssertEqual(draft, original)
    }

    func testValueDraftCannotModifyExistingTemplateSnapshot() {
        let existing = InspectionTemplateDraft(order: ["家电", "卫生间"])
        var draft = existing
        draft.move("家电", to: "卫生间")
        XCTAssertNil(draft.toggle("家电"))
        XCTAssertEqual(existing.order, ["家电", "卫生间"])
        XCTAssertTrue(existing.disabled.isEmpty)
    }

    @MainActor
    func testXiaodaSourceAssetDecodes() throws {
        let image = try XCTUnwrap(UIImage(named: "xiaoda-greet"))
        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 100)
    }

    #if DEBUG
    func testSetupReviewRequiresExplicitArgument() {
        XCTAssertNil(ReviewSurface.parse(["Xunju", "inspection-setup"]))
        XCTAssertEqual(ReviewSurface.parse(["Xunju", "--component-review", "inspection-setup"]), .inspectionSetup)
    }
    #endif
}
