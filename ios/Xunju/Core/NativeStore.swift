import Foundation
import JavaScriptCore
import Observation

struct HouseSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let archived: Bool
    let rent: String
    let area: String
    let address: String
    let decision: String
    let stats: InspectionStats
    let cover: String
    var card: HouseCardContent {
        HouseCardContent(name: name, rent: rent, address: address, area: area, decision: decision,
                         done: stats.done, total: stats.total, issues: stats.issues)
    }
}
struct InspectionStats: Decodable, Equatable { let done: Int; let total: Int; let issues: Int }
struct SaveStatus: Decodable, Equatable { let error: String; let blocked: Bool; let revision: Int }
struct HouseCapacity: Decodable, Equatable { let used: Int; let limit: Int; let remaining: Int; let packs: Int }
private struct CoreReply: Decodable {
    let ok: Bool
    let error: String
    let value: JSONValue
    let state: JSONValue
    let status: SaveStatus
    let capacity: HouseCapacity
    let summaries: [HouseSummary]
}

@MainActor @Observable
final class NativeStore {
    private(set) var state: JSONValue = .null
    private(set) var houses: [HouseSummary] = []
    private(set) var status = SaveStatus(error: "", blocked: false, revision: 0)
    private(set) var capacity = HouseCapacity(used: 0, limit: 2, remaining: 2, packs: 0)
    let records: LocalRecords
    @ObservationIgnored private let context: JSContext

    init(directory: URL, packs: Int = 0) throws {
        records = try LocalRecords(directory: directory)
        guard let context = JSContext(), let source = Bundle.main.url(forResource: "XunjuCore", withExtension: "js") else {
            throw CoreFailure(message: "清单规则资源缺失")
        }
        self.context = context
        let records = records
        let write: @convention(block) (String, Bool) -> String = { text, keepPrevious in
            do { try records.write(text, keepPrevious: keepPrevious); return "" }
            catch { return error.localizedDescription }
        }
        let preserve: @convention(block) () -> String = {
            do { try records.preserveCorrupt(); return "" }
            catch { return error.localizedDescription }
        }
        let previous: @convention(block) () -> String = {
            let result: [String: String]
            do { result = ["value": try records.read(previous: true), "error": ""] }
            catch { result = ["value": "", "error": error.localizedDescription] }
            return String(data: try! JSONEncoder().encode(result), encoding: .utf8)!
        }
        context.setObject(previous, forKeyedSubscript: "nativePrevious" as NSString)
        context.setObject(write, forKeyedSubscript: "nativeWrite" as NSString)
        context.setObject(preserve, forKeyedSubscript: "nativePreserveCorrupt" as NSString)
        context.evaluateScript(try String(contentsOf: source, encoding: .utf8), withSourceURL: source)
        try checkException()
        let result = context.objectForKeyedSubscript("XunjuCore")?.invokeMethod("initialize", withArguments: [
            try records.read(), packs
        ])
        _ = try consume(result)
    }

    var activeHouses: [HouseSummary] { houses.filter { !$0.archived } }
    var archivedHouses: [HouseSummary] { houses.filter(\.archived) }
    func house(_ id: String) -> JSONValue { state["houses"].array.first { $0.id == id } ?? .null }

    @discardableResult
    func call(_ operation: String, _ parameters: [String: JSONValue] = [:]) throws -> JSONValue {
        var request = parameters
        request["operation"] = .string(operation)
        let data = try JSONEncoder().encode(JSONValue.object(request))
        guard let json = String(data: data, encoding: .utf8) else { throw CoreFailure(message: "操作数据编码失败") }
        context.exception = nil
        return try consume(context.objectForKeyedSubscript("XunjuCore")?.invokeMethod("dispatch", withArguments: [json]))
    }

    @discardableResult
    func add(_ name: String) throws -> String { try call("add", ["value": .string(name)]).string }
    func answer(_ id: String, field: String, property: String = "value", value: JSONValue) throws {
        try call("answer", ["id": .string(id), "field": .string(field), "property": .string(property), "value": value])
    }
    func archive(_ id: String, archived: Bool) throws {
        try call("archive", ["id": .string(id), "value": .bool(archived)])
    }
    func form(_ id: String, phase: String = "全部", query: String = "", filters: [String] = [], folds: [String: Bool] = [:]) throws -> [JSONValue] {
        try call("form", ["id": .string(id), "view": .object(["phase": .string(phase), "query": .string(query),
            "filters": .array(filters.map(JSONValue.string))]), "folds": .object(folds.mapValues(JSONValue.bool))]).array
    }

    private func checkException() throws {
        if let exception = context.exception, !exception.isUndefined {
            throw CoreFailure(message: "清单规则执行失败：\(exception.toString() ?? "未知错误")")
        }
    }
    private func consume(_ result: JSValue?) throws -> JSONValue {
        try checkException()
        guard let json = result?.toString(), let data = json.data(using: .utf8) else {
            throw CoreFailure(message: "清单规则未返回有效结果")
        }
        let reply = try JSONDecoder().decode(CoreReply.self, from: data)
        if state != reply.state { state = reply.state }
        if houses != reply.summaries { houses = reply.summaries }
        if status != reply.status { status = reply.status }
        if capacity != reply.capacity { capacity = reply.capacity }
        guard reply.ok else { throw CoreFailure(message: reply.error) }
        return reply.value
    }
}
