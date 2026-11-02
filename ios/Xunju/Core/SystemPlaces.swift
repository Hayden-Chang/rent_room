import MapKit
import CoreLocation

struct NativePlace: Equatable, Sendable {
    let name: String
    let address: String
    let point: GeographicPoint
}

@MainActor protocol NativePlacesClient: Sendable {
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace]
    func reverse(_ point: GeographicPoint) async throws -> NativePlace?
}

/// SDK requests are local to each operation, so cancelling one picker cannot
/// cancel another picker's request. No Tianditu credentials are involved.
@MainActor struct SystemPlacesClient: NativePlacesClient {
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.resultTypes = [.address, .pointOfInterest]
        request.regionPriority = .default
        if let center {
            request.region = MKCoordinateRegion(center: center.coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000)
        }
        let search = MKLocalSearch(request: request)
        let cancel: @MainActor @Sendable () -> Void = { search.cancel() }
        return try await perform(cancel: cancel) { complete in
            search.start { response, error in
                if let error { complete(.failure(error)) }
                else { complete(.success(response?.mapItems.compactMap(Self.place) ?? [])) }
            }
        }
    }

    func reverse(_ point: GeographicPoint) async throws -> NativePlace? {
        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            request.preferredLocale = AppLanguage.shared.value.locale
            let cancel: @MainActor @Sendable () -> Void = { request.cancel() }
            return try await perform(cancel: cancel) { complete in
                request.getMapItems { items, error in
                    if let error { complete(.failure(error)) }
                    else { complete(.success(items?.compactMap(Self.place).first)) }
                }
            }
        } else {
            let geocoder = CLGeocoder()
            let cancel: @MainActor @Sendable () -> Void = { geocoder.cancelGeocode() }
            return try await perform(cancel: cancel) { complete in
                geocoder.reverseGeocodeLocation(location, preferredLocale: AppLanguage.shared.value.locale) { values, error in
                    Task { @MainActor in
                        if let error { complete(.failure(error)) }
                        else { complete(.success(values?.first.map { NativePlace(name: $0.name ?? "", address: Self.address($0), point: point) })) }
                    }
                }
            }
        }
    }

    func perform<T: Sendable>(deadline: Duration = .seconds(12), cancel: @escaping @MainActor @Sendable () -> Void,
                              start: (@escaping @MainActor @Sendable (Result<T, Error>) -> Void) -> Void) async throws -> T {
        let request = SystemPlaceRequest<T>(cancel: cancel)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                request.continuation = continuation
                request.timer = Task { @MainActor [weak request] in
                    do { try await Task.sleep(for: deadline) } catch { return }
                    request?.finish(.failure(URLError(.timedOut)), cancelRequest: true)
                }
                start { [weak request] result in request?.finish(result) }
            }
        } onCancel: {
            Task { @MainActor in request.finish(.failure(CancellationError()), cancelRequest: true) }
        }
    }

    static func place(_ item: MKMapItem) -> NativePlace? {
        let coordinate: CLLocationCoordinate2D, address: String
        if #available(iOS 26.0, *) {
            coordinate = item.location.coordinate
            address = item.address?.fullAddress ?? item.name ?? ""
        } else {
            coordinate = item.placemark.coordinate
            address = Self.address(item.placemark)
        }
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return NativePlace(name: item.name ?? address, address: address,
                           point: GeographicPoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
    private static func address(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        for value in [placemark.administrativeArea, placemark.locality, placemark.subLocality,
                      placemark.thoroughfare, placemark.subThoroughfare, placemark.name].compactMap({ $0 }) where !value.isEmpty {
            if !parts.contains(value) { parts.append(value) }
        }
        return parts.joined(separator: " ")
    }
}

/// Own the caller's completion independently of the SDK's cancellation callback.
/// MainActor serialization makes deadline, cancellation and late callbacks finish exactly once.
@MainActor private final class SystemPlaceRequest<Value: Sendable> {
    var continuation: CheckedContinuation<Value, Error>?
    var timer: Task<Void, Never>?
    private var cancel: (@MainActor @Sendable () -> Void)?
    init(cancel: @escaping @MainActor @Sendable () -> Void) { self.cancel = cancel }
    func finish(_ result: Result<Value, Error>, cancelRequest: Bool = false) {
        guard let continuation else { return }
        self.continuation = nil
        timer?.cancel(); timer = nil
        let stop = cancel; cancel = nil
        // Settle before cancel: an SDK may synchronously invoke its callback from cancel().
        continuation.resume(with: result)
        if cancelRequest { stop?() }
    }
}

@MainActor struct NativePlaceService {
    var client: any NativePlacesClient = SystemPlacesClient()
    func query(_ keyword: String, center: GeographicPoint?) async throws -> [PlaceChoice] {
        do {
            try Task.checkCancellation()
            if !keyword.isEmpty {
                // An existing house/pin must not bias a new city, state or country
                // query. Keep Apple's relevance order; distance is display-only.
                do {
                    let result = try await client.search(keyword, center: nil)
                    try Task.checkCancellation()
                    return choices(result, center: center, nearestFirst: false)
                } catch let error as MKError where error.code == .placemarkNotFound {
                    try Task.checkCancellation()
                    return []
                }
            }
            guard let center else { return [] }
            guard CLLocationCoordinate2DIsValid(center.coordinate) else { throw CoreFailure(message: "地点无效") }
            async let address = outcome { try await client.reverse(center) }
            async let nearby = outcome { try await client.search(AppCopy.text("小区"), center: center) }
            let (resolved, candidates) = await (address, nearby)
            try Task.checkCancellation()
            let places = choices((try? candidates.get()) ?? [], center: center, nearestFirst: true)
            if let location = try? resolved.get(), !location.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let selected = PlaceChoice(id: "center", name: location.name.isEmpty ? location.address : location.name,
                                           address: location.address, distance: "选点位置", point: center)
                return [selected] + places.filter { $0.address != selected.address || $0.point != center }
            }
            if case .failure = resolved, case .failure = candidates { throw CoreFailure(message: "地点查询失败，请重试或手动填写地址") }
            return places
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            throw CoreFailure(message: "地点查询失败，请重试或手动填写地址")
        }
    }
    private func outcome<T: Sendable>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await operation()) } catch { return .failure(error) }
    }
    private func choices(_ values: [NativePlace], center: GeographicPoint?, nearestFirst: Bool) -> [PlaceChoice] {
        var seen: Set<String> = []
        let origin = center.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let candidates = values.compactMap { value -> (PlaceChoice, Double)? in
            let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let street = value.address.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = name.isEmpty || street.contains(name) ? street : street + " " + name
            guard !street.isEmpty, CLLocationCoordinate2DIsValid(value.point.coordinate) else { return nil }
            let id = "\(value.point.latitude),\(value.point.longitude):\(name):\(address)"
            guard seen.insert(id).inserted else { return nil }
            let meters = origin?.distance(from: CLLocation(latitude: value.point.latitude, longitude: value.point.longitude))
            let distance = meters.map { $0 < 1000 ? "\(Int($0.rounded()))米" : String(format: "%.1f公里", $0 / 1000) } ?? ""
            return (PlaceChoice(id: id, name: name.isEmpty ? address : name, address: address, distance: distance, point: value.point), meters ?? .infinity)
        }
        return (nearestFirst ? candidates.sorted { $0.1 < $1.1 } : candidates).prefix(10).map(\.0)
    }
}
