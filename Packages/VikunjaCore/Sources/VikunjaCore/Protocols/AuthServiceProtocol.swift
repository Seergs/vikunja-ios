public protocol AuthServiceProtocol: Sendable {
    /// For a password login, `AuthSession.token` is an opaque persisted-
    /// credential blob (not the raw JWT) — callers must only pass it through
    /// to `AccountStoreProtocol`, never parse it, exactly as they already
    /// treat an API token string.
    func login(_ credentials: LoginCredentials) async throws -> AuthSession
    func loginWithAPIToken(_ token: String) async throws -> AuthSession
    func logout() async
}

public struct AuthSession: Equatable, Sendable {
    public let token: String
    public let user: User

    public init(token: String, user: User) {
        self.token = token
        self.user = user
    }
}
