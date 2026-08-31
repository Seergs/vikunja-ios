import Foundation

public struct User: Identifiable, Equatable, Sendable {
    public let id: Int
    public var username: String
    public var name: String?
    public var email: String?
    /// The project new tasks default into (`default_project_id` on the Vikunja
    /// user), or `nil` when the user hasn't set one. Vikunja reports an unset
    /// value as `0`; the mapper normalizes that to `nil`.
    public var defaultProjectID: Int?

    public init(
        id: Int,
        username: String,
        name: String? = nil,
        email: String? = nil,
        defaultProjectID: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.name = name
        self.email = email
        self.defaultProjectID = defaultProjectID
    }
}
