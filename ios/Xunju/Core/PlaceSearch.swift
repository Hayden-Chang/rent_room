import Foundation
import Observation

extension GeographicPoint {
    var json: JSONValue { .object(["latitude": .number(latitude), "longitude": .number(longitude)]) }
    init?(_ value: JSONValue) {
        guard let latitude = value["latitude"].number, let longitude = value["longitude"].number,
              latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }
}

@MainActor @Observable final class PlaceSearch {
    var query = ""
    private(set) var center: GeographicPoint?
    private(set) var choices: [PlaceChoice] = []
    private(set) var busy = false
    var message = ""
    private(set) var permissionDenied = false
    @ObservationIgnored let store: NativeStore
    @ObservationIgnored private let key: String
    @ObservationIgnored private let validScope: () -> Bool
    @ObservationIgnored private var results: [String: JSONValue] = [:]
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private let locator = NativeLocation()

    init(store: NativeStore, key: String, location: JSONValue = .null, validScope: @escaping () -> Bool) {
        self.store = store; self.key = key; self.validScope = validScope
        center = nativePoint(location)
    }
    func nativePoint(_ value: JSONValue) -> GeographicPoint? {
        guard GeographicPoint(value) != nil else { return nil }
        return (try? store.call("coordinate", ["property": .string("fromMap"), "value": value])).flatMap(GeographicPoint.init)
    }
    private func storedPoint(_ value: GeographicPoint) throws -> JSONValue {
        try store.call("coordinate", ["property": .string("toMap"), "value": value.json])
    }
    func start(address: String = "") {
        if center != nil { submit() }
        else if !address.isEmpty { query = address; submit() }
    }
    @discardableResult func submit(debounce: Bool = false) -> Task<Void, Never>? {
        cancel(); permissionDenied = false; message = ""; choices = []; results = [:]
        guard validScope() else { message = "账号已变化，请重新打开页面"; return nil }
        guard !key.isEmpty else { message = "地点查询暂不可用，请手动填写地址"; return nil }
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines), center = center, version = epoch
        guard !keyword.isEmpty || center != nil else { return nil }
        busy = true
        operation = Task { @MainActor in
            defer { if epoch == version { busy = false } }
            do {
                if debounce { try await Task.sleep(for: .milliseconds(300)) }
                var parameters: [String: JSONValue] = ["key": .string(key)]
                if let center { parameters["center"] = try storedPoint(center) }
                if !keyword.isEmpty { parameters["query"] = .string(keyword) }
                let value = try await store.query(keyword.isEmpty ? "nearbyPlaces" : "searchPlaces", parameters)
                try Task.checkCancellation()
                guard validScope(), epoch == version else { return }
                var records: [String: JSONValue] = [:]
                choices = value.array.compactMap { item in
                    guard !item.id.isEmpty, let point = nativePoint(item["location"]) else { return nil }
                    records[item.id] = item
                    return PlaceChoice(id: item.id, name: item["name"].string, address: item["address"].string, distance: item["distanceText"].string, point: point)
                }
                results = records
                if choices.isEmpty { message = "暂未查到地点，请重试或手动填写地址" }
            } catch is CancellationError {} catch {
                if validScope(), epoch == version { message = error.localizedDescription }
            }
        }
        return operation
    }
    func moved(_ point: GeographicPoint) {
        // Ignore initial camera updates and sub-metre rounding, avoiding a
        // recenter/query loop. An actual pan updates nearby results.
        if let center, abs(center.latitude - point.latitude) < 0.00001 && abs(center.longitude - point.longitude) < 0.00001 { return }
        center = point; if query.isEmpty { submit(debounce: true) }
    }
    func locate() {
        cancel(); let version = epoch; busy = true; message = ""; permissionDenied = false
        operation = Task { @MainActor in
            do {
                let point = try await locator.request(); try Task.checkCancellation()
                guard validScope(), epoch == version else { return }
                center = point; query = ""; submit()
            } catch is CancellationError {} catch {
                if validScope(), epoch == version { message = error.localizedDescription; permissionDenied = (error as? LocationFailure) == .denied; busy = false }
            }
        }
    }
    func selected(_ choice: PlaceChoice) throws -> JSONValue {
        guard validScope(), let value = results[choice.id] else { throw CoreFailure(message: "地点结果已变化，请重新查询") }
        return value
    }
    func didSelect(_ choice: PlaceChoice) { center = choice.point; query = ""; submit() }
    func synchronizeLocation(_ value: JSONValue) {
        let point = nativePoint(value)
        if point != center { cancel(); center = point; choices = []; results = [:] }
    }
    func reset() { cancel(); center = nil; query = ""; choices = []; results = [:]; message = ""; permissionDenied = false }
    func cancel() { epoch += 1; operation?.cancel(); operation = nil; locator.cancel(); busy = false }
}
