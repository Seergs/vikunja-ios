public protocol TaskRepositoryProtocol: Sendable {
    func fetchTasks(projectID: Int) async throws -> [VikunjaTask]
    func fetchTask(id: Int) async throws -> VikunjaTask
    func create(_ task: VikunjaTask) async throws -> VikunjaTask
    func update(_ task: VikunjaTask) async throws -> VikunjaTask
    func delete(id: Int) async throws
}
