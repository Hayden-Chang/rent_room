import XCTest
@testable import Xunju

@MainActor final class CurrencyIntegrationTests: XCTestCase {
    private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "currency-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root, freeLimit: 3)
    }
    private func settings() -> RegionalSettingsModel {
        let name = "currency-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return RegionalSettingsModel(defaults: defaults, preferredLanguages: ["zh-Hans"])
    }
    func testDefaultChangesOnlyNewHousesAndPersistsAmountsAndCurrency() throws {
        let store = try store(), settings = settings()
        store.currencyProvider = { settings.preferences.currencyCode }
        let usd = try store.add("放弃")
        try store.answer(usd, field: "f1_6", value: .string("2500"))
        settings.detect(countryCode: "GB")
        let gbp = try store.add("英国房源")
        settings.selectCurrency("EUR")
        let eur = try store.add("欧洲房源")
        settings.detect(countryCode: "JP")
        let restored = try NativeStore(directory: store.records.directory, freeLimit: 3)
        XCTAssertEqual(restored.house(usd)["currencyCode"].string, "USD")
        XCTAssertEqual(restored.house(usd)["answers"]["f1_6"]["value"].string, "2500")
        XCTAssertEqual(restored.house(usd)["name"].string, "放弃")
        XCTAssertEqual(restored.house(gbp)["currencyCode"].string, "GBP")
        XCTAssertEqual(restored.house(eur)["currencyCode"].string, "EUR")
        XCTAssertEqual(settings.preferences.currencyCode, "EUR")
    }
    func testLegacyMigrationImportAndExportRetainCurrencyWithoutConversion() async throws {
        let store = try store(), id = try store.add("旧房源")
        try store.answer(id, field: "f1_6", value: .string("1800"))
        let legacy = store.state.setting("houses", to: .array([store.house(id).removing("currencyCode")]))
        try store.records.write(String(decoding: JSONEncoder().encode(legacy), as: UTF8.self), keepPrevious: false)
        let restored = try NativeStore(directory: store.records.directory, freeLimit: 3)
        XCTAssertEqual(restored.house(id)["currencyCode"].string, "CNY")
        XCTAssertEqual(restored.house(id)["answers"]["f1_6"]["value"].string, "1800")
        let imported = try restored.call("prepareImport", ["value": legacy]).array
        XCTAssertEqual(imported.first?["currencyCode"].string, "CNY")
        try restored.call("import", ["houses": .array(imported), "replaceIds": .array([.string(id)])])
        let backup = NativeBackup(), output = store.records.directory.appending(path: "currency.zip")
        try await backup.export(houses: [restored.house(id)], root: store.records.directory, to: output)
        let exported = try await backup.preview(output).manifest
        XCTAssertEqual(exported["houses"].array.first?["currencyCode"].string, "CNY")
        let invalid = restored.house(id).setting("currencyCode", to: .string("INVALID"))
        let before = restored.state
        XCTAssertThrowsError(try restored.call("import", ["houses": .array([invalid]), "replaceIds": .array([.string(id)])]))
        XCTAssertEqual(restored.state, before)
    }
    func testComparisonShowsDifferentCurrenciesForSameAmountAndKeepsFreeTextRaw() throws {
        let store = try store()
        store.currencyProvider = { "GBP" }; let gbp = try store.add("GBP")
        store.currencyProvider = { "USD" }; let usd = try store.add("USD")
        for id in [gbp, usd] { try store.answer(id, field: "f1_6", value: .string("2000")) }
        try store.call("summary", ["id": .string(gbp), "property": .string("summary"), "value": .string("未填写")])
        let rows = try store.call("compare", ["ids": .array([.string(gbp), .string(usd)]), "differences": .bool(true)]).array
        let rent = try XCTUnwrap(rows.first { $0.id == "f1_6" })
        XCTAssertEqual(rent["values"].array.map(\.string), ["GBP 2000", "USD 2000"])
        let all = try store.call("compare", ["ids": .array([.string(gbp), .string(usd)])]).array
        XCTAssertEqual(all.first { $0.id == "summary" }?["localized"].array, [.bool(false), .bool(true)])
    }
    func testCurrencyPromptDoesNotLocateBeforeChoiceAndDeclineRemainsUSD() async {
        let settings = settings(), locator = CountryProbe()
        let flow = CurrencyLocationFlow(settings: settings, locator: locator)
        flow.afterChecklist(false); XCTAssertFalse(flow.showsPrompt)
        flow.afterChecklist(true); XCTAssertTrue(flow.showsPrompt); XCTAssertEqual(locator.calls, 0)
        flow.decline(); flow.afterChecklist(true); flow.refreshOnForeground()
        await Task.yield()
        XCTAssertFalse(flow.showsPrompt); XCTAssertEqual(locator.calls, 0)
        XCTAssertEqual(settings.preferences.currencyCode, "USD")
        XCTAssertTrue(settings.preferences.currencyPromptHandled)
    }
    func testExplicitLocationSuccessFailureAndManualChoiceWinOverLateResult() async {
        let settings = settings(), locator = CountryProbe()
        let flow = CurrencyLocationFlow(settings: settings, locator: locator)
        flow.request(); await locator.waitForRequest()
        locator.finish(.success("GB")); await finish(flow)
        XCTAssertEqual(settings.preferences.currencyCode, "GBP")
        flow.refreshOnForeground(); await locator.waitForRequest()
        locator.finish(.failure(LocationFailure.denied)); await finish(flow)
        XCTAssertEqual(settings.preferences.currencyCode, "USD")
        XCTAssertEqual(flow.messageKey, "location.unavailable")
        flow.request(); await locator.waitForRequest()
        flow.chooseCurrency("EUR"); locator.finish(.success("JP")); await Task.yield()
        XCTAssertEqual(settings.preferences.currencyCode, "EUR"); XCTAssertFalse(flow.busy)
    }
    func testBackgroundCancellationDoesNotOverwriteCurrencyOrRestartWithoutConsent() async {
        let settings = settings(), locator = CountryProbe()
        settings.detect(countryCode: "GB")
        let flow = CurrencyLocationFlow(settings: settings, locator: locator)
        flow.request(); await locator.waitForRequest(); flow.enterBackground()
        locator.finish(.success("JP")); await Task.yield()
        XCTAssertEqual(settings.preferences.currencyCode, "GBP"); XCTAssertFalse(flow.busy)
        XCTAssertFalse(flow.showsPrompt)
        flow.chooseCurrency("EUR"); let count = locator.calls; flow.refreshOnForeground(); await Task.yield()
        XCTAssertEqual(locator.calls, count)
    }
    func testOfflineWorkspaceKeepsCurrencyPreferenceAndSnapshotsAcrossRestart() throws {
        let suite = "offline-currency.\(UUID().uuidString)", root = FileManager.default.temporaryDirectory.appending(path: suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let first = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), regionalDefaults: defaults)
        first.regional.selectCurrency("CNY")
        let yuan = try first.store.add("人民币房源")
        try first.store.answer(yuan, field: "f1_6", value: .string("2000")); first.save()
        first.regional.selectCurrency("EUR")
        let second = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), regionalDefaults: defaults)
        let euro = try second.store.add("欧元房源")
        XCTAssertEqual(second.store.records.directory, first.store.records.directory)
        XCTAssertEqual(second.store.house(yuan)["currencyCode"].string, "CNY")
        XCTAssertEqual(second.store.house(yuan)["answers"]["f1_6"]["value"].string, "2000")
        XCTAssertEqual(second.store.house(euro)["currencyCode"].string, "EUR")
        XCTAssertEqual(second.store.state["iosReview"]["created"].int, 2)
    }
    func testCurrencyLabelsIncludeCodeWhenCanonicalCostHasNoUnit() {
        let prior = AppLanguage.shared.value; AppLanguage.shared.value = .chinese
        defer { AppLanguage.shared.value = prior }
        XCTAssertEqual(AppCopy.moneyLabel("物业费", currency: "USD"), "物业费（USD）")
        XCTAssertEqual(AppCopy.moneyLabel("单元清洁", currency: "GBP", verbatim: true), "单元清洁（GBP）")
        XCTAssertEqual(AppCopy.moneyLabel("电费（元/度）", currency: "EUR"), "电费（EUR/度）")
    }
    private func finish(_ flow: CurrencyLocationFlow) async {
        let deadline = ContinuousClock.now + .seconds(3)
        while flow.busy && ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(flow.busy)
    }
}

@MainActor private final class CountryProbe: CountryLocating {
    var mayRefreshWithoutPrompt = true
    var calls = 0
    private var reply: CheckedContinuation<String?, Error>?
    func country() async throws -> String? {
        calls += 1
        return try await withCheckedThrowingContinuation { reply = $0 }
    }
    func waitForRequest() async {
        let deadline = ContinuousClock.now + .seconds(3)
        while reply == nil && ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertNotNil(reply)
    }
    func finish(_ result: Result<String?, Error>) { let current = reply; reply = nil; current?.resume(with: result) }
    // Simulate a provider that delivers its callback after cancellation.
    func cancel() {}
}
