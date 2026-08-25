import Foundation

public struct VikunjaTask: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public var title: String
    public var description: String?
    public var isDone: Bool
    public var dueDate: Date?
    public var priority: Priority
    public var projectID: Int
    public var labels: [Label]

    public init(
        id: Int,
        title: String,
        description: String? = nil,
        isDone: Bool = false,
        dueDate: Date? = nil,
        priority: Priority = .unset,
        projectID: Int,
        labels: [Label] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isDone = isDone
        self.dueDate = dueDate
        self.priority = priority
        self.projectID = projectID
        self.labels = labels
    }

    public enum Priority: Int, Sendable, CaseIterable, Hashable {
        case unset = 0
        case low = 1
        case medium = 2
        case high = 3
        case urgent = 4
        case doNow = 5
    }
}
