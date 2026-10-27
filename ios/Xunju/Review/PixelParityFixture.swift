#if DEBUG
import Foundation

/// Screenshot preconditions only. A valid UUID business-test scope is required by the caller.
/// Values match the isolated WeChat screenshot fixture; this never uses an account or Keychain.
@MainActor enum PixelParityFixture {
    static func populate(_ store: NativeStore) throws {
        try store.call("setFreeLimit", ["value": .number(3)])
        try store.call("templateSelect", ["value": .string("detailed")])
        for (name, address, rent, area, archived) in [
            ("阳光小区", "朝阳路18号", "3200", "68", false),
            ("新城公寓", "新城路8号", "2800", "52", false),
            ("已归档房源", "朝阳路18号", "3200", "68", true)
        ] {
            let id = try store.add(name)
            try store.answer(id, field: "f1_1", value: .string(address))
            try store.answer(id, field: "f1_6", value: .string(rent))
            try store.answer(id, field: "f1_3", value: .string(area))
            if name != "新城公寓" {
                try store.call("summary", ["id": .string(id), "property": .string("decision"), "value": .string("继续比较")])
                try store.call("summary", ["id": .string(id), "property": .string("summary"), "value": .string("交通方便，继续比较。")])
            }
            if archived { try store.archive(id, archived: true) }
        }
        try store.call("setFreeLimit", ["value": .number(1)])
    }
}
#endif
