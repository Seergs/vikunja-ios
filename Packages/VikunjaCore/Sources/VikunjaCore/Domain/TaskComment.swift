import Foundation

/// A comment posted on a task, in the order Vikunja returns them.
public struct TaskComment: Identifiable, Equatable, Sendable {
    public let id: Int
    public var comment: String
    public var author: User
    public var created: Date
    public var updated: Date

    public init(id: Int, comment: String, author: User, created: Date, updated: Date) {
        self.id = id
        self.comment = comment
        self.author = author
        self.created = created
        self.updated = updated
    }
}
