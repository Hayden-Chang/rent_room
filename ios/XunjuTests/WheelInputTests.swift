import XCTest
@testable import Xunju

final class WheelInputTests: XCTestCase {
    func testPolicyRangesFixedOptionsAndManualExclusions() throws {
        let fields = WheelFieldSpec.all
        XCTAssertEqual(fields.count, 8)
        for id in ["f5_3", "f1_6", "f88_0", "f11_1", "617bd84f-3208-42ec-b2e4-5bb95d5c754c", "d244dc92-351e-4f3c-8738-45295fec9ff9", "cost_custom", "f1_3", "fc76beec-52e3-4fe9-a937-dec254d4cc4f", "f1_5", "f44_0", "f44_1", "f41_3", "21255282-3663-4abe-b7de-d91eeb3825ed", "f6_0"] { XCTAssertNil(fields[id]) }
        for spec in fields.values where spec.values == nil {
            let min = try XCTUnwrap(spec.min), max = try XCTUnwrap(spec.max), step = try XCTUnwrap(spec.step)
            XCTAssertEqual(spec.choices.first?.value, "")
            XCTAssertEqual(Double(spec.key(spec.choices[1].value)), min)
            XCTAssertEqual(Double(spec.key(try XCTUnwrap(spec.choices.last).value)), max)
            XCTAssertEqual(spec.choices.count, Int(((max - min) / step).rounded()) + 2)
            for index in 2..<spec.choices.count {
                let next = try XCTUnwrap(Double(spec.key(spec.choices[index].value)))
                let previous = try XCTUnwrap(Double(spec.key(spec.choices[index - 1].value)))
                XCTAssertEqual(next - previous, step, accuracy: 0.0001)
            }
        }
        XCTAssertEqual(fields["f88_1"]?.step, 0.5)
        XCTAssertEqual(fields["f88_2"]?.max, 12)

    }

    func testDraftDistinguishesEmptyZeroAndNetChanges() throws {
        let spec = try XCTUnwrap(WheelFieldSpec.all["f88_1"])
        var draft = WheelInputDraft(spec: spec, value: "0.50")
        XCTAssertFalse(draft.changed)
        draft.select(1); XCTAssertEqual(draft.value, "0"); XCTAssertTrue(draft.changed)
        draft.select(2); XCTAssertEqual(draft.value, "0.50"); XCTAssertFalse(draft.changed)
        draft.clear(); XCTAssertEqual(draft.value, ""); XCTAssertTrue(draft.changed)
        let empty = WheelInputDraft(spec: spec, value: "")
        XCTAssertEqual(empty.index, 0); XCTAssertFalse(empty.changed)
    }

    func testHistoricalValuesAndFormerOtherAreNeverClamped() throws {
        for (id, value) in [("f88_1", "20"), ("f88_1", "0.25"), ("f112_5", "12个月押金"), ("f112_2", "其他")] {
            let spec = try XCTUnwrap(WheelFieldSpec.all[id])
            let draft = WheelInputDraft(spec: spec, value: value)
            XCTAssertEqual(draft.value, value); XCTAssertFalse(draft.changed)
            XCTAssertEqual(draft.choices[draft.index].value, value)
            XCTAssertFalse(draft.choices[draft.index].label.contains("原记录"))
            if id == "f88_1", value == "20" { XCTAssertEqual(draft.index, draft.choices.count - 1); XCTAssertEqual(draft.choices[draft.index].label, "20 个月") }
            if id == "f88_1", value == "0.25" {
                XCTAssertEqual(draft.choices[draft.index - 1].value, "0")
                XCTAssertEqual(draft.choices[draft.index + 1].value, "0.5")
            }
        }
        let spec = try XCTUnwrap(WheelFieldSpec.all["f112_5"])
        var draft = WheelInputDraft(spec: spec, value: "3个月押金")
        draft.select(draft.index)
        XCTAssertEqual(draft.value, "3个月押金"); XCTAssertFalse(draft.changed)
        XCTAssertEqual(WheelFieldSpec.all["f116_1"]?.key("当天"), "0")
        XCTAssertEqual(spec.fixedSuffix, "押金")
        XCTAssertEqual(draft.choices[draft.index].wheelLabel, "3 个月")
        XCTAssertEqual(draft.choices[draft.index].label, "3 个月押金")
        XCTAssertEqual(spec.choices[0].wheelLabel, "未填写")
    }

    func testReviewRequiresExplicitArgument() {
        XCTAssertEqual(ReviewSurface.parse(["--component-review", "wheels"]), .wheels)
        XCTAssertNil(ReviewSurface.parse(["wheels"]))
        XCTAssertNil(ReviewSurface.parse(["--component-review", "unknown"]))
    }
}
