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
    let currencyCode: String
    var card: HouseCardContent {
        HouseCardContent(name: name, rent: rent, address: address, area: area, decision: decision,
                         done: stats.done, total: stats.total, issues: stats.issues, currencyCode: currencyCode)
    }
}
struct InspectionStats: Decodable, Equatable { let done: Int; let total: Int; let issues: Int }
struct SaveStatus: Decodable, Equatable { let error: String; let blocked: Bool; let revision: Int }
struct HouseCapacity: Decodable, Equatable { let used: Int; let limit: Int; let remaining: Int; let packs: Int }
private struct CoreReply: Decodable {
    let ok: Bool
    let error: String
    let valueIsState: Bool?
    let status: SaveStatus
    let capacity: HouseCapacity
    let summaries: [HouseSummary]?
}

@MainActor @Observable
final class NativeStore {
    private(set) var state: JSONValue = .null
    private(set) var houses: [HouseSummary] = []
    private(set) var status = SaveStatus(error: "", blocked: false, revision: 0)
    private(set) var capacity = HouseCapacity(used: 0, limit: 1, remaining: 1, packs: 0)
    let records: LocalRecords
    @ObservationIgnored var currencyProvider: () -> String = { "USD" }
    @ObservationIgnored private let context: JSContext
    @ObservationIgnored private let mapQueryTimeout: Duration

    init(directory: URL, packs: Int = 0, freeLimit: Int = 1, creditAccount: String = "local", network: any MapTransport = NativeMapTransport(), mapQueryTimeout: Duration = .seconds(15), firstVisit: Bool = false, exampleLanguage: SupportedLanguage = .chinese, developmentCreditsEnabled: Bool = true) throws {
        records = try LocalRecords(directory: directory)
        guard let context = JSContext(), let source = Bundle.main.url(forResource: "XunjuCore", withExtension: "js") else {
            throw CoreFailure(message: "清单规则资源缺失")
        }
        self.context = context
        self.mapQueryTimeout = mapQueryTimeout
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
        let readCredits: @convention(block) () -> String = {
            let result: [String: String]
            do { result = ["value": try records.readCredits(), "error": ""] }
            catch { result = ["value": "", "error": error.localizedDescription] }
            return String(data: try! JSONEncoder().encode(result), encoding: .utf8)!
        }
        let writeCredits: @convention(block) (String) -> String = { text in
            do { try records.writeCredits(text); return "" }
            catch { return error.localizedDescription }
        }
        context.setObject(readCredits, forKeyedSubscript: "nativeReadCredits" as NSString)
        context.setObject(writeCredits, forKeyedSubscript: "nativeWriteCredits" as NSString)
        context.setObject(previous, forKeyedSubscript: "nativePrevious" as NSString)
        context.setObject(write, forKeyedSubscript: "nativeWrite" as NSString)
        context.setObject(preserve, forKeyedSubscript: "nativePreserveCorrupt" as NSString)
        let prepareExamples: @convention(block) () -> String = {
            do { try ExampleHouseMedia.prepare(in: records.directory); return "" }
            catch { return error.localizedDescription }
        }
        context.setObject(prepareExamples, forKeyedSubscript: "nativePrepareExamples" as NSString)
        let request: @convention(block) (String, JSValue, JSValue) -> Void = { input, success, failure in
            MainActor.assumeIsolated {
                let callbacks = MapCallbacks(success: success, failure: failure)
                Task { @MainActor in
                    do { callbacks.resolve(try await network.request(input)) }
                    catch { callbacks.reject(error.localizedDescription) }
                }
            }
        }
        context.setObject(request, forKeyedSubscript: "nativeMapRequest" as NSString)
        context.evaluateScript(try String(contentsOf: source, encoding: .utf8), withSourceURL: source)
        try checkException()
        let missing = !FileManager.default.fileExists(atPath: directory.appending(path: "state.json").path)
        let hasPrevious = FileManager.default.fileExists(atPath: directory.appending(path: "state.previous.json").path)
        let raw: Any
        if missing { raw = NSNull() } else { raw = try records.read() }
        #if DEBUG
        let developmentCredits = developmentCreditsEnabled
        #else
        // The test seam can disable grants in Debug, but cannot enable them in Release.
        let developmentCredits = false
        #endif
        let result = context.objectForKeyedSubscript("XunjuCore")?.invokeMethod("initialize", withArguments: [
            raw, packs, freeLimit, creditAccount, firstVisit && !hasPrevious, exampleLanguage.rawValue, developmentCredits
        ])
        _ = try consume(result)
    }

    var activeHouses: [HouseSummary] { houses.filter { !$0.archived } }
    #if DEBUG
    func grantDevelopmentCredits() throws { try call("grantDevelopmentCredits") }
    #endif
    var archivedHouses: [HouseSummary] { houses.filter(\.archived) }
    func house(_ id: String) -> JSONValue { state["houses"].array.first { $0.id == id } ?? .null }

    @discardableResult
    func call(_ operation: String, _ parameters: [String: JSONValue] = [:]) throws -> JSONValue {
        var request = parameters
        if operation == "add" { request["currencyCode"] = .string(currencyProvider()) }
        request["operation"] = .string(operation)
        let data = try JSONEncoder().encode(JSONValue.object(request))
        guard let json = String(data: data, encoding: .utf8) else { throw CoreFailure(message: "操作数据编码失败") }
        context.exception = nil
        return try consume(context.objectForKeyedSubscript("XunjuCore")?.invokeMethod("dispatch", withArguments: [json, true]))
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
        try call("form", ["id": .string(id), "view": .object(["phase": .string(phase), "query": .string(query), "queryTerms": .array(AppCopy.searchTerms(query).map(JSONValue.string)),
            "filters": .array(filters.map(JSONValue.string))]), "folds": .object(folds.mapValues(JSONValue.bool))]).array
    }

    func query(_ operation: String, _ parameters: [String: JSONValue]) async throws -> JSONValue {
        var input = parameters; input["operation"] = .string(operation)
        let json = String(decoding: try JSONEncoder().encode(JSONValue.object(input)), as: UTF8.self)
        let once = MapReply()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                once.start(continuation, timeout: mapQueryTimeout)
                let complete: @convention(block) (String) -> Void = { text in
                    MainActor.assumeIsolated { once.finish(text) }
                }
                // Explicit conversion keeps this callback callable on iOS 18;
                // implicit block conversion inside the argument array fails.
                guard let callback = JSValue(object: complete, in: context) else {
                    once.fail(CoreFailure(message: "地点查询未能启动")); return
                }
                context.exception = nil
                let promise = context.objectForKeyedSubscript("XunjuCore")?.invokeMethod("dispatchAsync", withArguments: [json, callback])
                if let exception = context.exception, !exception.isUndefined { once.fail(CoreFailure(message: "地点查询未能启动")) }
                else { once.retain(promise) }
            }
        } onCancel: {
            Task { @MainActor in once.fail(CancellationError()) }
        }
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
        guard var envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoreFailure(message: "清单规则未返回有效结果")
        }
        // Decode the large, heterogeneous payload once without repeatedly probing
        // Codable types; retain strict typed validation for the small metadata.
        var snapshot = try envelope.removeValue(forKey: "state").map(JSONValue.init(jsonObject:))
        if let rawDelta = envelope.removeValue(forKey: "stateDelta") {
            snapshot = try StateDelta.apply(JSONValue(jsonObject: rawDelta), to: state)
        }
        let value = try JSONValue(jsonObject: envelope.removeValue(forKey: "value") ?? NSNull())
        let reply = try JSONDecoder().decode(CoreReply.self, from: JSONSerialization.data(withJSONObject: envelope))
        if let snapshot, state != snapshot { state = snapshot }
        if let summaries = reply.summaries, houses != summaries { houses = summaries }
        if status != reply.status { status = reply.status }
        if capacity != reply.capacity { capacity = reply.capacity }
        guard reply.ok else { throw CoreFailure(message: reply.error) }
        return reply.valueIsState == true ? state : value
    }
}

@MainActor private final class MapCallbacks {
    let success: JSValue
    let failure: JSValue
    init(success: JSValue, failure: JSValue) { self.success = success; self.failure = failure }
    func resolve(_ text: String) { success.call(withArguments: [text]) }
    func reject(_ text: String) { failure.call(withArguments: [text]) }
}

@MainActor private final class MapReply {
    private var continuation: CheckedContinuation<JSONValue, Error>?
    private var promise: JSValue?
    private var deadline: Task<Void, Never>?
    private var completed = false
    func start(_ continuation: CheckedContinuation<JSONValue, Error>, timeout: Duration) {
        self.continuation = continuation
        deadline = Task { @MainActor in
            do { try await Task.sleep(for: timeout) } catch { return }
            fail(CoreFailure(message: "查询超时，请重试或返回手动填写"))
        }
    }
    func retain(_ value: JSValue?) { if !completed { promise = value } }
    func finish(_ text: String) {
        do {
            let reply = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
            guard reply["ok"].bool else { throw CoreFailure(message: reply["error"].string) }
            settle(.success(reply["value"]))
        } catch { fail(error) }
    }
    func fail(_ error: Error) { settle(.failure(error)) }
    private func settle(_ result: Result<JSONValue, Error>) {
        guard !completed else { return }
        completed = true
        deadline?.cancel(); deadline = nil; promise = nil
        let pending = continuation; continuation = nil
        pending?.resume(with: result)
    }
}
