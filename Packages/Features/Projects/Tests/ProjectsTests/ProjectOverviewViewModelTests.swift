import Testing
import VikunjaCore
@testable import Projects

@MainActor
struct ProjectOverviewViewModelTests {
    @Test
    func loadFetchesTheProjectsTasks() async {
        let repository = FakeTaskRepository()
        repository.tasks = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Review PR", projectID: 1),
            VikunjaTask(id: 3, title: "Other project's task", projectID: 2),
        ]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.tasks.map(\.id) == [1, 2])
    }

    @Test
    func loadSurfacesAFriendlyMessageOnFailure() async {
        let repository = FakeTaskRepository()
        repository.fetchError = .network("offline")
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
        #expect(viewModel.tasks.isEmpty)
    }
}
