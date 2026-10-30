import XCTest
@testable import Xunju

final class BridgeJSONTests: XCTestCase {
    func testFoundationConversionMatchesCodableForNestedSchema() throws {
        let text = #"{"zero":0,"one":1,"negative":-42,"decimal":90.5,"yes":true,"no":false,"empty":null,"text":"备注 🏠\n保留","array":[0,1,true,false,null,{"unknownLegacyKey":"原样"}],"object":{}}"#
        let data = Data(text.utf8)
        let converted = try JSONValue(jsonObject: JSONSerialization.jsonObject(with: data))
        XCTAssertEqual(converted, try JSONDecoder().decode(JSONValue.self, from: data))
        XCTAssertEqual(converted["zero"], .number(0)); XCTAssertEqual(converted["one"], .number(1))
        XCTAssertEqual(converted["yes"], .bool(true)); XCTAssertEqual(converted["no"], .bool(false))
        XCTAssertEqual(converted, try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(converted)))
    }
    func testScalarAndEmptyPayloadsRemainLossless() throws {
        for text in ["null", "false", "true", "0", "1", "-2.5", "[]", "{}", "\"\"", "1e10"] {
            let data = Data(text.utf8)
            XCTAssertEqual(try JSONValue(jsonObject: JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)),
                           try JSONDecoder().decode(JSONValue.self, from: data), text)
        }
        XCTAssertThrowsError(try JSONValue(jsonObject: Date()))
    }
}
