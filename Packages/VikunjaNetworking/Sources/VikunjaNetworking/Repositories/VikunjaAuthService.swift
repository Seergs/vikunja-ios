import Foundation
import VikunjaCore

/// Implements login against `/api/v1/login`. Persisting the token (Keychain,
/// multi-account) is `VikuAuth`'s responsibility — this service only knows
/// how to talk to the endpoint.
public final class VikunjaAuthService: AuthServiceProtocol {
    private let client: APIClient
    private let baseURL: URL

    public init(client: APIClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    /// `/api/v1/login` only returns the JWT, not the user — that's why
    /// `AuthSession.user` is a placeholder here; resolving the real user
    /// (GET /api/v1/user) is future work, same as today.
    ///
    /// The returned `AuthSession.token` is an opaque, JSON-encoded
    /// `PasswordSessionCredential` — not the raw JWT — carrying a refresh
    /// token too when the server sets one (a v2.0+ instance's
    /// `vikunja_refresh_token` cookie). Callers must only pass it through to
    /// `AccountStoreProtocol`, never parse it.
    public func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        let (tokenDTO, response): (AuthTokenDTO, HTTPURLResponse) = try await client.sendWithResponse(
            VikunjaEndpoints.login(credentials),
        )

        let refreshToken = HTTPCookie.cookies(
            withResponseHeaderFields: (response.allHeaderFields as? [String: String]) ?? [:],
            for: baseURL,
        ).first { $0.name == "vikunja_refresh_token" }?.value

        let sessionCredential = PasswordSessionCredential(accessToken: tokenDTO.token, refreshToken: refreshToken)
        let encoded = try JSONEncoder().encode(sessionCredential)
        let opaqueToken = String(data: encoded, encoding: .utf8) ?? ""
        return AuthSession(token: opaqueToken, user: User(id: 0, username: credentials.username))
    }

    public func loginWithAPIToken(_ token: String) async throws -> AuthSession {
        AuthSession(token: token, user: User(id: 0, username: ""))
    }

    public func logout() async {}
}
