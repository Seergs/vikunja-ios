import Foundation
import VikunjaCore

enum TaskMapper {
    /// Vikunja's API represents "no due date" as this zero-value timestamp rather than `null`.
    private static let noDueDateSentinel = ISO8601DateFormatter().date(from: "0001-01-01T00:00:00Z")!

    private static func dueDate(from dto: TaskDTO) -> Date? {
        guard let dueDate = dto.dueDate, dueDate != noDueDateSentinel else { return nil }
        return dueDate
    }

    /// Reads one relation kind out of `dto.relatedTasks`, falling back to
    /// this task's own project for any entry missing its `project_id`.
    private static func relations(_ dto: TaskDTO, kind: String) -> [TaskRelation] {
        (dto.relatedTasks?[kind] ?? []).map { TaskRelationMapper.toDomain($0, fallbackProjectID: dto.projectId) }
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
            labels: (dto.labels ?? []).map(LabelMapper.toDomain),
            subtasks: relations(dto, kind: "subtask"),
            dependsOn: relations(dto, kind: "blocked"),
            blocks: relations(dto, kind: "blocking")
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

    /// Builds the safe body for `VikunjaTaskRepository.update(_:)`: starts
    /// from `current` (the task's just-fetched full state) and overwrites
    /// only the fields `VikunjaTask` tracks, leaving everything else —
    /// including fields our domain model doesn't represent at all — exactly
    /// as the server last reported them. See `TaskDTO`'s doc comment for why
    /// this exists.
    static func merge(_ task: VikunjaTask, onto current: TaskDTO) -> TaskDTO {
        TaskDTO(
            id: current.id,
            title: task.title,
            description: task.description,
            done: task.isDone,
            dueDate: task.dueDate,
            priority: task.priority.rawValue,
            projectId: task.projectID,
            labels: task.labels.map(LabelMapper.toDTO),
            relatedTasks: current.relatedTasks,
            doneAt: current.doneAt,
            startDate: current.startDate,
            endDate: current.endDate,
            reminders: current.reminders,
            repeatAfter: current.repeatAfter,
            repeatMode: current.repeatMode,
            hexColor: current.hexColor,
            percentDone: current.percentDone,
            assignees: current.assignees,
            coverImageAttachmentId: current.coverImageAttachmentId,
            isFavorite: current.isFavorite
        )
    }
}
