import Foundation

/// Tolerant mirror of the `/api/v1/tasks` JSON. Field names must be confirmed
/// against a real instance's swagger docs (`/api/v1/docs`) before integrating with
/// an actual Vikunja server — this is the only place to touch if the server changes
/// the shape of this resource.
struct TaskDTO: Codable {
    let id: Int
    let title: String
    let description: String?
    let done: Bool
    let dueDate: Date?
    let priority: Int?
    let projectId: Int
    let labels: [LabelDTO]?
    /// Keyed by Vikunja's relation-kind strings ("subtask", "blocked",
    /// "blocking", ...) — only the kinds `TaskMapper` currently reads are
    /// documented there; the rest tolerate decoding but are otherwise
    /// unused. Never populated by `TaskMapper.toDTO(_:)`: Vikunja manages
    /// relations through their own endpoint, not the task create/update
    /// body, so there's nothing meaningful to send back here.
    let relatedTasks: [String: [RelatedTaskDTO]]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, done, priority, labels
        case dueDate = "due_date"
        case projectId = "project_id"
        case relatedTasks = "related_tasks"
    }
}
