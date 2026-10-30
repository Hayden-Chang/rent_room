import CoreLocation
import Observation

@MainActor protocol CountryLocating {
    var mayRefreshWithoutPrompt: Bool { get }
    func country() async throws -> String?
    func cancel()
}

/// A single foreground location request. Coordinates are not persisted or sent
/// to the app server; Apple's geocoder supplies only the ISO country identifier.
@MainActor final class SystemCountryLocation: CountryLocating {
    private let location = NativeLocation()
    private let geocoder = CLGeocoder()
    var mayRefreshWithoutPrompt: Bool { location.isAuthorized }

    func country() async throws -> String? {
        let point = try await location.request()
        try Task.checkCancellation()
        let deadline = Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled { geocoder.cancelGeocode() }
        }
        defer { deadline.cancel() }
        return try await withTaskCancellationHandler {
            let result = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: point.latitude, longitude: point.longitude))
            try Task.checkCancellation()
            return result.first?.isoCountryCode
        } onCancel: { Task { @MainActor in self.cancel() } }
    }
    func cancel() { location.cancel(); geocoder.cancelGeocode() }
}

@MainActor @Observable final class CurrencyLocationFlow {
    var showsPrompt = false
    var showsManualSelection = false
    private(set) var busy = false
    private(set) var messageKey = ""
    @ObservationIgnored private let settings: RegionalSettingsModel
    @ObservationIgnored private let locator: any CountryLocating
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var epoch = 0

    init(settings: RegionalSettingsModel, locator: any CountryLocating = SystemCountryLocation()) {
        self.settings = settings; self.locator = locator
    }
    func afterChecklist(_ completed: Bool) {
        guard completed, !settings.preferences.currencyPromptHandled else { return }
        showsPrompt = true
    }
    func presentPrompt() { messageKey = ""; showsPrompt = true }
    func chooseManual() {
        cancel(); settings.markCurrencyPromptHandled(); showsPrompt = false; showsManualSelection = true
    }
    func decline() {
        cancel(); settings.declineLocation(); showsPrompt = false; messageKey = ""
    }
    func chooseCurrency(_ code: String?) {
        cancel(); settings.selectCurrency(code); messageKey = ""
        if code == nil { showsManualSelection = false; presentPrompt() }
    }
    func request() {
        settings.beginLocationDetection()
        resolve()
    }
    func refreshOnForeground() {
        guard settings.preferences.currencySelection == .automatic,
              settings.preferences.automaticLocationRequested == true,
              locator.mayRefreshWithoutPrompt, !busy else { return }
        resolve()
    }
    private func resolve() {
        cancel(); let version = epoch; busy = true; messageKey = ""
        task = Task { @MainActor in
            do {
                let country = try await locator.country()
                try Task.checkCancellation()
                guard epoch == version else { return }
                settings.detect(countryCode: country)
                if country == nil { messageKey = "location.unavailable" }
            } catch is CancellationError {
                return
            } catch {
                guard epoch == version, !Task.isCancelled else { return }
                settings.detect(countryCode: nil); messageKey = "location.unavailable"
            }
            guard epoch == version else { return }
            busy = false; showsPrompt = false; task = nil
        }
    }
    func cancel() {
        epoch += 1; task?.cancel(); task = nil; locator.cancel(); busy = false
    }
    func enterBackground() { cancel(); showsPrompt = false }
}
