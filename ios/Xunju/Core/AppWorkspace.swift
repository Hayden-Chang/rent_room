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
    let scopes: LocalIdentityScopes
    private(set) var store: NativeStore
    private(set) var session: LocalSession?
    var error = ""
    @ObservationIgnored private let keychain: any SessionStorage
    @ObservationIgnored let mapKey: String
    @ObservationIgnored let places: NativePlaceService
    @ObservationIgnored private let mapTransport: any MapTransport
    private(set) var identityRevision = 0
    @ObservationIgnored private(set) var billing: CapacityController!
    @ObservationIgnored private let policyAPI: any CapacityPolicyServicing
    @ObservationIgnored private let policyCache: CapacityPolicyCache
    private(set) var capacityPolicy: CapacityPolicy
    private(set) var policyError = ""
    @ObservationIgnored private var refreshingPolicy = false

    init(root: URL, keychain: any SessionStorage = SessionKeychain(), mapTransport: any MapTransport = NativeMapTransport(), mapKey: String = NativeConfiguration.current.tiandituKey, places: NativePlaceService = NativePlaceService(), capacityAPI: any CapacityServicing = CapacityAPI(), storefront: (any CapacityStorefront)? = nil, policyAPI: any CapacityPolicyServicing = CapacityPolicyAPI()) throws {
        self.keychain = keychain
        self.mapTransport = mapTransport; self.mapKey = mapKey
        self.places = places
        scopes = try LocalIdentityScopes(root: root)
        self.policyAPI = policyAPI; policyCache = CapacityPolicyCache(root: scopes.root)
        let initialPolicy = policyCache.read()
        capacityPolicy = initialPolicy
        let guest = try NativeStore(directory: scopes.guestDirectory(), freeLimit: initialPolicy.freeLimit, network: mapTransport)
        if let saved = try keychain.read() {
            try saved.validateStored()
            let account = try NativeStore(directory: scopes.accountDirectory(saved.account), packs: saved.packs, freeLimit: initialPolicy.freeLimit, network: mapTransport)
            if account.status.blocked {
                // Expose the existing recovery banner without attempting a guest claim or write.
                store = account
            } else {
                store = try scopes.claim(account: saved.account, from: guest, packs: saved.packs, freeLimit: initialPolicy.freeLimit, network: mapTransport)
            }
            session = saved
        } else { store = guest }
        billing = CapacityController(workspace: self, api: capacityAPI, storefront: storefront ?? NativeStorefront())
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
        #endif
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
        store = target; session = verified; identityRevision += 1; billing.identityChanged()
    }
    func logout() throws {
        try store.call("save")
        guard store.status.error.isEmpty else { throw CoreFailure(message: store.status.error) }
        let guest = try NativeStore(directory: scopes.guestDirectory(), freeLimit: capacityPolicy.freeLimit, network: mapTransport)
        try keychain.remove()
        store = guest; session = nil; identityRevision += 1; billing.identityChanged()
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
        try policyCache.write(policy)
        try store.call("setFreeLimit", ["value": .number(Double(policy.freeLimit))])
        capacityPolicy = policy; policyError = ""
    }
    func refreshPolicy() async {
        guard !refreshingPolicy else { return }
        refreshingPolicy = true; defer { refreshingPolicy = false }
        do { if let policy = try await policyAPI.fetch() { try acceptPolicy(policy) } }
        catch is CancellationError {} catch { policyError = error.localizedDescription }
    }
}

/// Explicit UI test runs never read or mutate the user's Keychain session.
@MainActor final class VolatileSessionStorage: SessionStorage {
    private var value: LocalSession?
    func read() -> LocalSession? { value }
    func write(_ session: LocalSession) { value = session }
    func remove() { value = nil }
}
