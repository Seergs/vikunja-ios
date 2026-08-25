import VikunjaCore

public final class VikunjaTaskRepository: TaskRepositoryProtocol {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func fetchTasks(projectID: Int) async throws -> [VikunjaTask] {
        let dtos: [TaskDTO] = try await client.send(VikunjaEndpoints.tasks(projectID: projectID))
        return dtos.map(TaskMapper.toDomain)
    }

    public func fetchTask(id: Int) async throws -> VikunjaTask {
        let dto: TaskDTO = try await client.send(VikunjaEndpoints.task(id: id))
        return TaskMapper.toDomain(dto)
    }

    public func create(_ task: VikunjaTask) async throws -> VikunjaTask {
        let endpoint = try VikunjaEndpoints.createTask(projectID: task.projectID, dto: TaskMapper.toDTO(task))
        let dto: TaskDTO = try await client.send(endpoint)
        return TaskMapper.toDomain(dto)
    }

    public func update(_ task: VikunjaTask) async throws -> VikunjaTask {
        let endpoint = try VikunjaEndpoints.updateTask(id: task.id, dto: TaskMapper.toDTO(task))
        let dto: TaskDTO = try await client.send(endpoint)
        return TaskMapper.toDomain(dto)
    }

    public func delete(id: Int) async throws {
        try await client.send(VikunjaEndpoints.deleteTask(id: id))
    }
}
