import VikunjaCore

enum TaskMapper {
    static func toDomain(_ dto: TaskDTO) -> VikunjaTask {
        VikunjaTask(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            isDone: dto.done,
            dueDate: dto.dueDate,
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
