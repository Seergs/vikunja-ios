import Testing
import VikunjaCore
@testable import Tasks

@MainActor
struct QuickAddTaskViewModelTests {
    @Test
    func startsWithNoProjectSelectedAndCannotSave() {
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository()
        )

        #expect(viewModel.selectedProjectID == nil)
        #expect(viewModel.canSave == false)
    }

    @Test
    func loadPopulatesNonArchivedProjectsSortedByPosition() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [
            Project(id: 1, title: "Later", isArchived: false, position: 2),
            Project(id: 2, title: "Archived", isArchived: true, position: 0),
            Project(id: 3, title: "First", isArchived: false, position: 1),
        ]
        let viewModel = QuickAddTaskViewModel(taskRepository: FakeTaskRepository(), projectRepository: projectRepository)

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.projects.map(\.id) == [3, 1])
    }

    @Test
    func loadSurfacesAFriendlyMessageOnFailure() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.fetchError = .network("offline")
        let viewModel = QuickAddTaskViewModel(taskRepository: FakeTaskRepository(), projectRepository: projectRepository)

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func canSaveRequiresBothATitleAndAProject() {
        let viewModel = QuickAddTaskViewModel(taskRepository: FakeTaskRepository(), projectRepository: FakeProjectRepository())

        viewModel.title = "   "
        viewModel.selectedProjectID = 1
        #expect(viewModel.canSave == false)

        viewModel.title = "Buy milk"
        viewModel.selectedProjectID = nil
        #expect(viewModel.canSave == false)

        viewModel.selectedProjectID = 1
        #expect(viewModel.canSave == true)
    }

    @Test
    func saveCreatesATaskWithTheChosenProjectAndPriority() async {
        let taskRepository = FakeTaskRepository()
        let viewModel = QuickAddTaskViewModel(taskRepository: taskRepository, projectRepository: FakeProjectRepository())
        viewModel.title = "  Buy milk  "
        viewModel.selectedProjectID = 7
        viewModel.priority = .high

        let created = await viewModel.save()

        #expect(created?.title == "Buy milk")
        #expect(created?.projectID == 7)
        #expect(created?.priority == .high)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test
    func saveDoesNothingWhenTheFormIsIncomplete() async {
        let taskRepository = FakeTaskRepository()
        let viewModel = QuickAddTaskViewModel(taskRepository: taskRepository, projectRepository: FakeProjectRepository())
        viewModel.title = "Buy milk"

        let created = await viewModel.save()

        #expect(created == nil)
    }

    @Test
    func saveSurfacesAFriendlyMessageOnFailure() async {
        let viewModel = QuickAddTaskViewModel(taskRepository: FailingTaskRepository(), projectRepository: FakeProjectRepository())
        viewModel.title = "Buy milk"
        viewModel.selectedProjectID = 1

        let created = await viewModel.save()

        #expect(created == nil)
        #expect(viewModel.saveErrorMessage == "Couldn't reach that server. Check the address and your connection.")
    }
}

private final class FailingTaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    func fetchTasks(projectID: Int) async throws -> [VikunjaTask] { [] }
    func fetchTask(id: Int) async throws -> VikunjaTask { throw VikunjaError.notFound }
    func create(_ task: VikunjaTask) async throws -> VikunjaTask { throw VikunjaError.network("offline") }
    func update(_ task: VikunjaTask) async throws -> VikunjaTask { task }
    func delete(id: Int) async throws {}
}
