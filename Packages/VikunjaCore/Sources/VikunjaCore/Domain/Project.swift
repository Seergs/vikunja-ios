import Foundation

public struct Project: Identifiable, Equatable, Sendable {
    public let id: Int
    public var title: String
    public var description: String?
    public var isArchived: Bool
    public var isFavorite: Bool
    public var parentProjectID: Int?

    public init(
        id: Int,
        title: String,
        description: String? = nil,
        isArchived: Bool = false,
        isFavorite: Bool = false,
        parentProjectID: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isArchived = isArchived
        self.isFavorite = isFavorite
        self.parentProjectID = parentProjectID
    }
}
