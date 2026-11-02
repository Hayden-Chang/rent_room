import XCTest

@MainActor extension XCTestCase {
    func assertRenderedSwipeProgress(_ app: XCUIApplication, prefix: String) throws {
        let raw = try XCTUnwrap(app.otherElements["teaching.motion"].value as? String)
        let samples = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [[String: Any]])
        let widths = samples.compactMap { $0["width"] as? Int }
        let trace = XCTAttachment(string: String(describing: widths)); trace.name = prefix + "-rendered-action-widths"; trace.lifetime = .keepAlways; add(trace)
        for (index, sample) in samples.enumerated() {
            let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(sample["png"] as? String)))
            let frame = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            frame.name = prefix + "-swipe-frame-\(index)-width-\(sample["width"] ?? 0)"; frame.lifetime = .keepAlways; add(frame)
        }
        XCTAssertTrue(widths.contains(0), "Capture must see the closed row: \(widths)")
        XCTAssertTrue(widths.contains { $0 >= 40 }, "Capture must see the fully revealed action: \(widths)")
        XCTAssertGreaterThanOrEqual(Set(widths.filter { (3...39).contains($0) }).count, 3,
            "The action must visibly slide through intermediate widths, not appear in one jump: \(widths)")
    }
}
