import Foundation
import VikunjaCore

enum TaskMapper {
    /// Vikunja's API represents "no due date" as this zero-value timestamp rather than `null`.
    private static let noDueDateSentinel = ISO8601DateFormatter().date(from: "0001-01-01T00:00:00Z")!

    private static func dueDate(from dto: TaskDTO) -> Date? {
        guard let dueDate = dto.dueDate, dueDate != noDueDateSentinel else { return nil }
        return dueDate
    }

    static func toDomain(_ dto: TaskDTO) -> VikunjaTask {
        VikunjaTask(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            isDone: dto.done,
            dueDate: dueDate(from: dto),
            priority: VikunjaTask.Priority(rawValue: dto.priority ?? 0) ?? .unset,
            projectID: dto.projectId,
            labels: (dto.labels ?? []).map(LabelMapper.toDomain)
        )
    }

    static func toDTO(_ task: VikunjaTask) -> TaskDTO {
        TaskDTO(
            id: task.id,
            title: task.title,
            description: task.description,
            done: task.isDone,
            dueDate: task.dueDate,
            priority: task.priority.rawValue,
            projectId: task.projectID,
            labels: task.labels.map(LabelMapper.toDTO)
        )
    }
}
