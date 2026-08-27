import Foundation

/// A configured connection to a Vikunja instance. The credential (API token)
/// is never stored here — it lives in the Keychain, referenced by `id`, behind
/// `AccountStoreProtocol`.
public struct InstanceAccount: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var displayName: String
    public var baseURL: URL
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        baseURL: URL,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.createdAt = createdAt
    }
}
