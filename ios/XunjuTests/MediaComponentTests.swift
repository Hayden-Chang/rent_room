import XCTest
@testable import Xunju

final class MediaComponentTests: XCTestCase {
    private func item(_ id: String, _ kind: MediaTile.Kind = .image) -> MediaTile {
        MediaTile(id: id, kind: kind, url: nil)
    }
    func testMixedAttachmentsPreserveOrderAndGiveVideosTheirOwnRow() {
        let items = [item("a"), item("b"), item("v", .video), item("c"), item("d"), item("e"), item("f"), item("w", .video)]
        let rows = IssueMediaRows.arrange(items)
        XCTAssertEqual(rows.map { $0.map(\.id) }, [["a", "b"], ["v"], ["c", "d", "e"], ["f"], ["w"]])
        XCTAssertEqual(rows.flatMap { $0 }, items)
    }
    func testEmptyAndConsecutiveVideosDoNotCreateEmptyRows() {
        XCTAssertEqual(IssueMediaRows.arrange([]), [])
        XCTAssertEqual(IssueMediaRows.arrange([item("v", .video), item("w", .video)]).map { $0.map(\.id) }, [["v"], ["w"]])
    }
    func testGalleryFiltersDoNotChangeCaptionsRelationsOrOrder() {
        var photo = item("a"); photo.caption = "需要复查\n窗框"; photo.relation = "窗户密封"
        let items = [photo, item("v", .video), item("b")]
        XCTAssertEqual(items.filter(MediaFilter.all.includes), items)
        XCTAssertEqual(items.filter(MediaFilter.images.includes), [photo, item("b")])
        XCTAssertEqual(items.filter(MediaFilter.videos.includes).map(\.id), ["v"])
    }
}
