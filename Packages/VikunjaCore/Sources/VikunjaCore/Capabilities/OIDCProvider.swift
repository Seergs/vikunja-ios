import Foundation

/// One OIDC provider an instance's admin has configured (e.g. Keycloak,
/// Authentik, Google). Vikunja hands the client everything needed to build
/// an authorization request itself — the frontend, not the OIDC provider's
/// discovery document, is the source of truth for `authURL`/`clientID`/
/// `scope` here.
public struct OIDCProvider: Equatable, Sendable, Codable, Identifiable {
    /// Vikunja's short identifier for this provider (e.g. `"authentik"`),
    /// also the path segment used by the login callback endpoint
    /// (`/api/v1/auth/openid/{key}/callback`).
    public let key: String
    public var id: String {
        key
    }

    public let name: String
    public let authURL: URL
    public let clientID: String
    public let scope: String

    public init(key: String, name: String, authURL: URL, clientID: String, scope: String) {
        self.key = key
        self.name = name
        self.authURL = authURL
        self.clientID = clientID
        self.scope = scope
    }
}
