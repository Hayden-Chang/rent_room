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
    private(set) var identityRevision = 0

    init(root: URL, keychain: any SessionStorage = SessionKeychain()) throws {
        self.keychain = keychain
        scopes = try LocalIdentityScopes(root: root)
        let guest = try NativeStore(directory: scopes.guestDirectory())
        if let saved = try keychain.read() {
            try saved.validateStored()
            store = try scopes.claim(account: saved.account, from: guest, packs: saved.packs)
            session = saved
        } else { store = guest }
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
        let target = try scopes.claim(account: verified.account, from: session == nil ? store : nil, packs: verified.packs)
        store = target; session = verified; identityRevision += 1
    }
    func logout() throws {
        try store.call("save")
        guard store.status.error.isEmpty else { throw CoreFailure(message: store.status.error) }
        let guest = try NativeStore(directory: scopes.guestDirectory())
        try keychain.remove()
        store = guest; session = nil; identityRevision += 1
    }
    func save() { perform { try store.call("save") } }
}

/// Explicit UI test runs never read or mutate the user's Keychain session.
@MainActor final class VolatileSessionStorage: SessionStorage {
    private var value: LocalSession?
    func read() -> LocalSession? { value }
    func write(_ session: LocalSession) { value = session }
    func remove() { value = nil }
}
