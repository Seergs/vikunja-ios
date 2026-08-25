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
