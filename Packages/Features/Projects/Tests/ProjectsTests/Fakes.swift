import VikunjaCore
@testable import Projects

final class FakeProjectRepository: ProjectRepositoryProtocol, @unchecked Sendable {
    var projects: [Project] = []
    var fetchError: VikunjaError?

    func fetchProjects() async throws -> [Project] {
        if let fetchError { throw fetchError }
        return projects
    }

    func fetchProject(id: Int) async throws -> Project {
        guard let project = projects.first(where: { $0.id == id }) else {
            throw VikunjaError.notFound
        }
        return project
    }

    func create(_ project: Project) async throws -> Project { project }

    func update(_ project: Project) async throws -> Project { project }

    func delete(id: Int) async throws {
        projects.removeAll { $0.id == id }
    }
}

final class FakeTaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    var tasks: [VikunjaTask] = []
    var fetchError: VikunjaError?
    var updateError: VikunjaError?

    func fetchTasks(projectID: Int) async throws -> [VikunjaTask] {
        if let fetchError { throw fetchError }
        return tasks.filter { $0.projectID == projectID }
    }

    func fetchTask(id: Int) async throws -> VikunjaTask {
        guard let task = tasks.first(where: { $0.id == id }) else {
            throw VikunjaError.notFound
        }
        return task
    }

    func create(_ task: VikunjaTask) async throws -> VikunjaTask { task }

    func update(_ task: VikunjaTask) async throws -> VikunjaTask {
        if let updateError { throw updateError }
        return task
    }

    func delete(id: Int) async throws {
        tasks.removeAll { $0.id == id }
    }
}
