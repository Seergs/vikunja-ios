import Foundation

public struct User: Identifiable, Equatable, Sendable {
    public let id: Int
    public var username: String
    public var name: String?
    public var email: String?

    public init(id: Int, username: String, name: String? = nil, email: String? = nil) {
        self.id = id
        self.username = username
        self.name = name
        self.email = email
    }
}
