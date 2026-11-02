import Foundation
import Observation

@MainActor protocol SessionStorage {
    func read() throws -> LocalSession?
    func write(_ session: LocalSession) throws
    func remove() throws
}
extension SessionKeychain: SessionStorage {}

/// One shared store for every page. Test data can only use a UUID-scoped sandbox.
@MainActor @Observable
final class AppWorkspace {
    let regional: RegionalSettingsModel
    let currencyLocation: CurrencyLocationFlow
    let scopes: LocalIdentityScopes
    private(set) var store: NativeStore
    private(set) var session: LocalSession?
    private(set) var purchaseBalance: CapacityBalance?
    @ObservationIgnored private let purchaseCache: PurchaseCapacityCache
    var error = ""
    @ObservationIgnored private let keychain: any SessionStorage
    @ObservationIgnored let mapKey: String
    @ObservationIgnored let places: NativePlaceService
    @ObservationIgnored private let mapTransport: any MapTransport
    private(set) var identityRevision = 0
    @ObservationIgnored private(set) var billing: CapacityController!
    private(set) var capacityPolicy: CapacityPolicy
    @ObservationIgnored private var purchaseLedger: PurchaseLedger?

    init(root: URL, keychain: any SessionStorage = SessionKeychain(), mapTransport: any MapTransport = NativeMapTransport(), mapKey: String = NativeConfiguration.current.tiandituKey, places: NativePlaceService = NativePlaceService(), storefront: (any CapacityStorefront)? = nil, regionalDefaults: UserDefaults? = nil, countryLocator: (any CountryLocating)? = nil, firstVisitExamples: Bool = false) throws {
        let firstVisit = firstVisitExamples && !FileManager.default.fileExists(atPath: root.path)
        let regional = RegionalSettingsModel(defaults: regionalDefaults ?? (Self.isBusinessTest ? UserDefaults(suiteName: "regional-business." + root.lastPathComponent)! : .standard))
        self.regional = regional
        currencyLocation = CurrencyLocationFlow(settings: regional, locator: countryLocator ?? SystemCountryLocation())
        self.keychain = keychain
        self.mapTransport = mapTransport; self.mapKey = mapKey
        self.places = places
        scopes = try LocalIdentityScopes(root: root)
        let initialPolicy = CapacityPolicy.initial
        capacityPolicy = initialPolicy
        let saved = FileManager.default.fileExists(atPath: scopes.root.appending(path: "local-current.json").path) ? nil : try keychain.read()
        if let saved { try saved.validateStored() }
        purchaseCache = PurchaseCapacityCache(root: scopes.root)
        let cached: CapacityBalance?
        do {
            let ledger = try PurchaseLedgerStorage(root: scopes.root).read()
            purchaseLedger = ledger
            cached = try ledger?.balance(policy: initialPolicy) ?? purchaseCache.read()
        }
        catch { purchaseLedger = nil; cached = try? purchaseCache.read(); self.error = error.localizedDescription }
        purchaseBalance = cached
        let effectivePolicy = initialPolicy
        capacityPolicy = effectivePolicy
        let legacyPacks = try purchaseCache.legacyPacks(seed: saved?.packs)
        let directory = try scopes.offlineDirectory(legacy: saved)
        store = try NativeStore(directory: directory, packs: cached?.packs ?? legacyPacks,
            freeLimit: effectivePolicy.freeLimit, creditAccount: cached?.account ?? "local", network: mapTransport, firstVisit: firstVisit && saved == nil, exampleLanguage: regional.language)
        // Resume only an already journalled migration; never claim another guest on launch.
        if let saved, directory == (try scopes.accountDirectory(saved.account)),
           FileManager.default.fileExists(atPath: directory.appending(path: "guest-claim.json").path), !store.status.blocked {
            store = try scopes.claim(account: saved.account, from: nil, packs: cached?.packs ?? saved.packs,
                freeLimit: capacityPolicy.freeLimit, network: mapTransport)
        }
        try scopes.selectOfflineDirectory(directory)
        session = saved // migration compatibility only; no production login UI or network use
        store.currencyProvider = { [regional] in regional.preferences.currencyCode }
        billing = CapacityController(workspace: self, storefront: storefront ?? NativeStorefront())
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let mode = FillingGuideFixture.mode(arguments) { try FillingGuideFixture.prepare(store, mode: mode) }
        if ReturningBusinessFixture.enabled(arguments) {
            if arguments.contains("--two-room-policy-fixture") { try acceptPolicy(CapacityPolicy(version: 2, freeLimit: 2)) }
            if store.state["xiaoda"]["setup"].string != "done" {
                try store.call("settings", ["property": .string("onboarding"), "value": .bool(false)])
                let legacy = store.state.removing("xiaoda")
                try store.records.write(String(decoding: JSONEncoder().encode(legacy), as: UTF8.self), keepPrevious: false)
                store = try NativeStore(directory: store.records.directory, packs: store.capacity.packs, freeLimit: capacityPolicy.freeLimit, network: mapTransport)
            }
        }
        if ReturningBusinessFixture.enabled(arguments), arguments.contains("--pixel-parity-fixture"), store.houses.isEmpty {
            try PixelParityFixture.populate(store)
        }
        if FilledChoiceFixture.enabled(arguments), store.houses.count == 3 {
            try FilledChoiceFixture.prepare(store)
            store = try NativeStore(directory: store.records.directory, packs: store.capacity.packs, freeLimit: capacityPolicy.freeLimit, network: mapTransport)
        }
        #endif
        store.currencyProvider = { [regional] in regional.preferences.currencyCode }
    }

    static func dataRoot(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> URL {
        #if DEBUG
        if let index = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(index + 1),
           let id = UUID(uuidString: arguments[index + 1]) {
            return FileManager.default.temporaryDirectory.appending(path: "XunjuBusinessTests/\(id.uuidString)")
        }
        #endif
        return try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true).appending(path: "Xunju")
    }
    static var isBusinessTest: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(index + 1) {
            return UUID(uuidString: arguments[index + 1]) != nil
        }
        #endif
        return false
    }
    @discardableResult
    func perform(_ work: () throws -> Void) -> Bool {
        do { try work(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func accept(_ receipt: LoginReceipt) throws {
        let verified = try LocalSession(receipt: receipt)
        try store.call("save")
        guard store.status.error.isEmpty else { throw CoreFailure(message: store.status.error) }
        // Persist verified identity first; claim's journal can resume after interruption.
        try keychain.write(verified)
        if let policy = receipt.capacity { try acceptPolicy(policy) }
        let target = try scopes.claim(account: verified.account, from: session == nil ? store : nil, packs: verified.packs, freeLimit: capacityPolicy.freeLimit, network: mapTransport)
        try scopes.selectOfflineDirectory(target.records.directory)
        store = target; store.currencyProvider = { [regional] in regional.preferences.currencyCode }; session = verified; identityRevision += 1; billing.identityChanged()
    }
    func logout() throws {
        try store.call("save")
        guard store.status.error.isEmpty else { throw CoreFailure(message: store.status.error) }
        let guest = try NativeStore(directory: scopes.guestDirectory(), freeLimit: capacityPolicy.freeLimit, network: mapTransport)
        try keychain.remove()
        try scopes.selectOfflineDirectory(guest.records.directory)
        store = guest; store.currencyProvider = { [regional] in regional.preferences.currencyCode }; session = nil; identityRevision += 1; billing.identityChanged()
    }
    func applyPurchaseCapacity(_ balance: CapacityBalance, identity: PurchaseIdentity) throws {
        _ = try balance.validated()
        guard balance.account == identity.account, balance.environment == identity.environment else {
            throw CoreFailure(message: "容量记录与当前 App Store 购买身份不一致")
        }
        if let old = purchaseBalance, old.account == balance.account, old.environment == balance.environment {
            if balance.revision < old.revision { return }
            guard balance.revision != old.revision || balance.packs == old.packs else {
                throw CoreFailure(message: "容量版本不一致，请稍后重试")
            }
        }
        // Persist local capacity before StoreKit.finish(); house data is never reduced.
        try purchaseCache.write(balance)
        if let policy = balance.capacity { try acceptPolicy(policy) }
        try store.call("setPurchaseContext", ["value": .object([
            "packs": .number(Double(balance.packs)), "account": .string(balance.account)
        ])])
        purchaseBalance = balance
    }
    func applyCapacity(_ balance: CapacityBalance) throws {
        _ = try balance.validated()
        guard let old = session, old.account == balance.account else { throw CoreFailure(message: "账号已变化，请重试") }
        if let environment = old.capacityEnvironment, environment != balance.environment { throw CoreFailure(message: "购买环境已变化，请重新登录后恢复容量") }
        if let revision = old.capacityRevision {
            if balance.revision < revision { return }
            guard balance.revision != revision || balance.packs == old.packs else { throw CoreFailure(message: "容量版本不一致，请稍后重试") }
        }
        let updated = old.withCapacity(balance)
        try keychain.write(updated)
        if let policy = balance.capacity { try acceptPolicy(policy) }
        try store.call("setPacks", ["value": .number(Double(balance.packs))])
        session = updated
    }
    func save() { perform { try store.call("save") } }
    func acceptPolicy(_ policy: CapacityPolicy) throws {
        _ = try policy.validated()
        try CapacityPolicy.validate(packs: store.capacity.packs, limit: policy.freeLimit + store.capacity.packs * 10, policy: policy)
        try store.call("setFreeLimit", ["value": .number(Double(policy.freeLimit))])
        capacityPolicy = policy
    }
    func isActivePurchase(_ id: String) -> Bool {
        guard let entry = purchaseLedger?.entries[id] else { return false }
        return entry.transaction.revocationDate == nil
    }
    var purchaseRevision: Int { purchaseLedger?.revision ?? 0 }
    func recordPurchases(_ transactions: [CapacityTransaction], identity: PurchaseIdentity, snapshotStartedAt: Int? = nil) throws {
        var ledger = purchaseLedger.flatMap { $0.account == identity.account ? $0 : nil }
            ?? PurchaseLedger(account: identity.account, environment: identity.environment)
        try ledger.apply(transactions, identity: identity, snapshotStartedAt: snapshotStartedAt,
                         minimumRevision: purchaseBalance?.revision ?? 0)
        let balance = try ledger.balance(policy: capacityPolicy)
        // If the subsequent cache write fails, the durable ledger is recovered on restart.
        try PurchaseLedgerStorage(root: scopes.root).write(ledger)
        purchaseLedger = ledger
        try applyPurchaseCapacity(balance, identity: identity)
    }
}
/// Explicit UI test runs never read or mutate the user's Keychain session.
@MainActor final class VolatileSessionStorage: SessionStorage {
    private var value: LocalSession?
    func read() -> LocalSession? { value }
    func write(_ session: LocalSession) { value = session }
    func remove() { value = nil }
}
