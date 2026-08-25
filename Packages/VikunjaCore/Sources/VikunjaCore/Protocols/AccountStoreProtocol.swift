import Foundation

/// Persists the user's configured Vikunja instance connections and tracks
/// which one is active. Implemented by a Keychain-backed store in
/// `VikunjaAuth` — account metadata and credentials must never live in
/// `UserDefaults`.
public protocol AccountStoreProtocol: Sendable {
    func fetchAccounts() async throws -> [InstanceAccount]
    func activeAccount() async throws -> InstanceAccount?

    /// Saves `account` and its `token`, and makes it the active account.
    func addAccount(_ account: InstanceAccount, token: String) async throws

    func removeAccount(id: InstanceAccount.ID) async throws
    func setActiveAccount(id: InstanceAccount.ID) async throws
    func token(forAccountID id: InstanceAccount.ID) async throws -> String?
}
