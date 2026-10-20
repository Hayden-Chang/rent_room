import Foundation
import Observation

enum UtilityField {
    static let transit = "21255282-3663-4abe-b7de-d91eeb3825ed"
    static let driving = "3c70cda2-7c6c-4fa6-b2db-b647af24ba72"
    static let speed = "d244dc92-351e-4f3c-8738-45295fec9ff9"
    static func mode(_ id: String) -> String? { id == transit ? "transit" : id == driving ? "driving" : nil }
}

@MainActor @Observable final class CommuteSearch {
    private(set) var endpoints: JSONValue = .null
    private(set) var routes: [CommuteRouteChoice] = []
    var selectedID = ""
    private(set) var busy = false
    var message = ""
    @ObservationIgnored let store: NativeStore
    @ObservationIgnored private let houseID: String, fieldID: String, key: String
    @ObservationIgnored private let validScope: () -> Bool
    @ObservationIgnored private let previous: JSONValue
    @ObservationIgnored private var stamp: JSONValue = .null
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var operation: Task<Void, Never>?

    init(store: NativeStore, houseID: String, fieldID: String, key: String, validScope: @escaping () -> Bool) {
        self.store = store; self.houseID = houseID; self.fieldID = fieldID; self.key = key; self.validScope = validScope
        previous = store.house(houseID)["answers"][fieldID]["value"]
    }
    var chosen: CommuteRouteChoice? { routes.first { $0.id == selectedID } }
    func nativePoint(_ value: JSONValue) -> GeographicPoint? {
        guard GeographicPoint(value) != nil else { return nil }
        return (try? store.call("coordinate", ["property": .string("fromMap"), "value": value])).flatMap(GeographicPoint.init)
    }
    @discardableResult func query() -> Task<Void, Never>? {
        cancel(); message = ""; routes = []; selectedID = ""
        do {
            guard validScope(), !store.house(houseID)["archived"].bool, let mode = UtilityField.mode(fieldID) else { throw CoreFailure(message: "房源不可编辑，请返回清单") }
            endpoints = try store.call("endpoints", ["id": .string(houseID)]); stamp = endpoints["stamp"]
            guard GeographicPoint(endpoints["origin"]["location"]) != nil, GeographicPoint(endpoints["destination"]["location"]) != nil else {
                throw CoreFailure(message: "请先在地图中选定房源与上班地点的位置")
            }
            let version = epoch, origin = endpoints["origin"]["location"], destination = endpoints["destination"]["location"]
            busy = true
            operation = Task { @MainActor in
                defer { if version == epoch { busy = false } }
                do {
                    let response = try await store.query("commuteRoutes", ["key": .string(key), "mode": .string(mode), "origin": origin, "destination": destination])
                    try Task.checkCancellation()
                    guard validScope(), version == epoch else { return }
                    guard try store.call("endpoints", ["id": .string(houseID)])["stamp"] == stamp else { throw CoreFailure(message: "地点已变化，请重新查询") }
                    routes = response.array.map { route in
                        CommuteRouteChoice(id: route.id, title: route["title"].string, minutes: route["minutes"].int, distance: route["distanceText"].string,
                                           walk: route["walkText"].string, transfers: route["transfers"].int, transit: mode == "transit",
                                           paths: route["polyline"].array.map { $0["points"].array.compactMap(nativePoint) })
                    }
                    selectedID = routes.first?.id ?? ""
                } catch is CancellationError {} catch { if version == epoch && validScope() { message = error.localizedDescription } }
            }
        } catch { message = error.localizedDescription }
        return operation
    }
    func confirm() throws {
        guard validScope(), !busy, let chosen else { throw CoreFailure(message: "请选择有效路线") }
        try store.call("computed", ["id": .string(houseID), "field": .string(fieldID),
                                    "value": .object(["amount": .number(Double(chosen.minutes)), "previous": previous, "stamp": stamp])])
    }
    func cancel() { epoch += 1; operation?.cancel(); operation = nil; busy = false }
}
