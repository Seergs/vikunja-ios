import Testing
import VikunjaCore
@testable import Projects

@MainActor
struct ProjectsListViewModelTests {
    @Test
    func loadBuildsATreeFromParentProjectID() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "Work", position: 1),
            Project(id: 2, title: "Personal", position: 2),
            Project(id: 3, title: "Work / Client A", parentProjectID: 1, position: 1),
            Project(id: 4, title: "Work / Client B", parentProjectID: 1, position: 2),
            Project(id: 5, title: "Work / Client A / Invoices", parentProjectID: 3, position: 1),
        ]
        let viewModel = ProjectsListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.rootNodes.map(\.project.id) == [1, 2])

        let work = viewModel.rootNodes[0]
        #expect(work.children.map(\.project.id) == [3, 4])
        #expect(work.children[0].children.map(\.project.id) == [5])
        #expect(viewModel.rootNodes[1].children.isEmpty)
    }

    @Test
    func loadOrdersSiblingsByPosition() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "Third", position: 3),
            Project(id: 2, title: "First", position: 1),
            Project(id: 3, title: "Second", position: 2),
        ]
        let viewModel = ProjectsListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.rootNodes.map(\.project.title) == ["First", "Second", "Third"])
    }

    @Test
    func loadExcludesArchivedProjects() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "Active"),
            Project(id: 2, title: "Archived", isArchived: true),
        ]
        let viewModel = ProjectsListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.rootNodes.map(\.project.id) == [1])
    }

    @Test
    func loadDropsAnArchivedParentsChildrenSinceTheyHaveNoAttachmentPoint() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "Archived parent", isArchived: true),
            Project(id: 2, title: "Orphaned child", parentProjectID: 1),
        ]
        let viewModel = ProjectsListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.rootNodes.isEmpty)
    }

    @Test
    func loadIsResilientToACyclicParentChain() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "A", parentProjectID: 2),
            Project(id: 2, title: "B", parentProjectID: 1),
        ]
        let viewModel = ProjectsListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.rootNodes.isEmpty)
    }

    @Test
    func loadSurfacesAFriendlyMessageOnFailure() async {
        let repository = FakeProjectRepository()
        repository.fetchError = .network("offline")
        let viewModel = ProjectsListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
        #expect(viewModel.rootNodes.isEmpty)
    }
}
