import Foundation

/// A configured connection to a Vikunja instance. The credential (an API
/// token, or an opaque password-session blob when `authMethod == .password`)
/// is never stored here — it lives in the Keychain, referenced by `id`,
/// behind `AccountStoreProtocol`.
public struct InstanceAccount: Identifiable, Hashable, Sendable, Codable {
    /// Which login method produced this account's stored credential.
    /// `.oidc` will join this once OIDC support lands.
    public enum AuthMethod: String, Sendable, Codable {
        case apiToken
        case password
    }

    public let id: UUID
    public var displayName: String
    public var baseURL: URL
    public var createdAt: Date
    public var authMethod: AuthMethod

    public init(
        id: UUID = UUID(),
        displayName: String,
        baseURL: URL,
        createdAt: Date = Date(),
        authMethod: AuthMethod = .apiToken,
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.createdAt = createdAt
        self.authMethod = authMethod
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case baseURL
        case createdAt
        case authMethod
    }

    /// Custom decoding so accounts already saved to a user's Keychain before
    /// `authMethod` existed (JSON with no such key) decode as `.apiToken`
    /// instead of failing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.baseURL = try container.decode(URL.self, forKey: .baseURL)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.authMethod = try container.decodeIfPresent(AuthMethod.self, forKey: .authMethod) ?? .apiToken
    }
}
