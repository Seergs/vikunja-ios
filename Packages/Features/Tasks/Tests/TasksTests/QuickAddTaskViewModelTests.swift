import Testing
import VikunjaCore
@testable import Tasks

@MainActor
struct QuickAddTaskViewModelTests {
    @Test
    func startsWithNoProjectSelectedAndCannotSave() {
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.projects.map(\.id) == [3, 1])
    }

    @Test
    func loadSurfacesAFriendlyMessageOnFailure() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.fetchError = .network("offline")
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func canSaveRequiresBothATitleAndAProject() {
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

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
        let viewModel = QuickAddTaskViewModel(
            taskRepository: taskRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
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
    func saveShowsASuccessToast() async {
        let taskRepository = FakeTaskRepository()
        let toastPresenter = FakeToastPresenter()
        let viewModel = QuickAddTaskViewModel(
            taskRepository: taskRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        viewModel.title = "Buy milk"
        viewModel.selectedProjectID = 7

        _ = await viewModel.save()

        #expect(toastPresenter.shownMessages.count == 1)
        #expect(toastPresenter.shownMessages.first?.message == "Task created")
        #expect(toastPresenter.shownMessages.first?.style == .success)
    }

    @Test
    func saveDoesNothingWhenTheFormIsIncomplete() async {
        let taskRepository = FakeTaskRepository()
        let viewModel = QuickAddTaskViewModel(
            taskRepository: taskRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        viewModel.title = "Buy milk"

        let created = await viewModel.save()

        #expect(created == nil)
    }

    @Test
    func projectGroupsArrangesTopLevelProjectsWithTheirDirectChildren() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [
            Project(id: 1, title: "Work", parentProjectID: nil, position: 0),
            Project(id: 2, title: "Redesign", parentProjectID: 1, position: 1),
            Project(id: 3, title: "Personal", parentProjectID: nil, position: 1),
            Project(id: 4, title: "Launch", parentProjectID: 1, position: 0),
        ]
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.projectGroups.map(\.root.id) == [1, 3])
        #expect(viewModel.projectGroups[0].children.map(\.id) == [4, 2])
        #expect(viewModel.projectGroups[1].children.isEmpty)
    }

    @Test
    func selectedProjectResolvesTheChosenIDAgainstTheLoadedProjects() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [Project(id: 1, title: "Work")]
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.load()

        #expect(viewModel.selectedProject == nil)

        viewModel.selectedProjectID = 1

        #expect(viewModel.selectedProject?.title == "Work")
    }

    @Test
    func saveSurfacesAFriendlyMessageOnFailure() async {
        let viewModel = QuickAddTaskViewModel(
            taskRepository: FailingTaskRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
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
    func searchTasks(query: String) async throws -> [VikunjaTask] { [] }
}
