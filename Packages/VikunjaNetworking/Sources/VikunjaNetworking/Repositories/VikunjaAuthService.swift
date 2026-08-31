import VikunjaCore

/// Implements login against `/api/v1/login`. Persisting the token (Keychain,
/// multi-account) is the responsibility of a future `VikunjaAuth` package — this
/// service only knows how to talk to the endpoint.
public final class VikunjaAuthService: AuthServiceProtocol {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// `/api/v1/login` only returns the JWT, not the user — that's why
    /// `AuthSession.user` is a placeholder here; resolving the real user
    /// (GET /api/v1/user) is future `VikunjaAuth` work, once it knows where to
    /// persist the token.
    public func login(username: String, password: String) async throws -> AuthSession {
        let endpoint = try VikunjaEndpoints.login(username: username, password: password)
        let tokenDTO: AuthTokenDTO = try await client.send(endpoint)
        return AuthSession(token: tokenDTO.token, user: User(id: 0, username: username))
    }

    public func loginWithAPIToken(_ token: String) async throws -> AuthSession {
        AuthSession(token: token, user: User(id: 0, username: ""))
    }

    public func logout() async {}
}
