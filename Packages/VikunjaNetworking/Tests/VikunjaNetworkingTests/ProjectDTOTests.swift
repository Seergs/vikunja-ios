import Foundation
import Testing
@testable import VikunjaNetworking

struct ProjectDTOTests {
    @Test
    func decodesRealisticProjectsPayload() throws {
        let dtos = try loadProjectDTOs()

        #expect(dtos.count == 3)
        #expect(dtos[0].title == "Inbox")
        #expect(dtos[0].parentProjectId == 0)
        #expect(dtos[2].parentProjectId == 6)
    }

    /// The real API's `parent_project_id` is a non-pointer `int64` on the
    /// server, so root-level projects come back as `0`, never absent/null —
    /// confirmed against a live instance's response. The mapper must
    /// normalize that `0` to `nil`, or `ProjectsListViewModel` can never find
    /// a root to attach the tree to.
    @Test
    func mapsRootLevelZeroParentIDToNil() throws {
        let dtos = try loadProjectDTOs()
        let projects = dtos.map(ProjectMapper.toDomain)

        #expect(projects[0].parentProjectID == nil)
        #expect(projects[1].parentProjectID == nil)
        #expect(projects[2].parentProjectID == 6)
    }

    private func loadProjectDTOs() throws -> [ProjectDTO] {
        let url = try #require(Bundle.module.url(forResource: "projects", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ProjectDTO].self, from: data)
    }
}
