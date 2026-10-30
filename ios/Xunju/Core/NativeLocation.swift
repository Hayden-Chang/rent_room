import CoreLocation

enum LocationFailure: LocalizedError, Equatable {
    case denied, unavailable
    var errorDescription: String? { self == .denied ? "定位权限未开启，请在设置中允许访问位置" : "未能取得当前位置，请重试或手动搜索地址" }
}

@MainActor final class NativeLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var reply: CheckedContinuation<GeographicPoint, Error>?
    private var timeout: Task<Void, Never>?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }

    var isAuthorized: Bool { [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) }

    func request() async throws -> GeographicPoint {
        guard reply == nil else { throw LocationFailure.unavailable }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { reply in
                self.reply = reply
                timeout = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(15))
                    if !Task.isCancelled { finish(.failure(LocationFailure.unavailable)) }
                }
                if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
                else { requestAuthorized() }
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    func cancel() { finish(.failure(CancellationError())) }
    private func requestAuthorized() {
        guard reply != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(.failure(LocationFailure.denied))
        default: break
        }
    }
    private func finish(_ value: Result<GeographicPoint, Error>) {
        let current = reply; reply = nil
        timeout?.cancel(); timeout = nil; manager.stopUpdatingLocation()
        current?.resume(with: value)
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in requestAuthorized() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let value = locations.last
        let point = value.map { GeographicPoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        let valid = value.map { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 60 && CLLocationCoordinate2DIsValid($0.coordinate) } ?? false
        Task { @MainActor in
            if valid, let point { finish(.success(point)) } else { finish(.failure(LocationFailure.unavailable)) }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor in finish(.failure(denied ? LocationFailure.denied : .unavailable)) }
    }
}
