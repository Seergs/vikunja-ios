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
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
        #expect(viewModel.tasks.isEmpty)
    }

    @Test
    func loadCarriesTheSubprojectsHandedInAtConstruction() async {
        let repository = FakeTaskRepository()
        let subprojects = [ProjectNode(project: Project(id: 2, title: "Client A", parentProjectID: 1))]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            subprojects: subprojects,
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        #expect(viewModel.subprojects.map(\.project.id) == [2])
    }

    @Test
    func loadFetchesEachSubprojectsOwnTaskSummary() async {
        let repository = FakeTaskRepository()
        repository.tasks = [
            VikunjaTask(id: 1, title: "Parent task", projectID: 1),
            VikunjaTask(id: 2, title: "Client A task 1", isDone: true, projectID: 2),
            VikunjaTask(id: 3, title: "Client A task 2", isDone: false, projectID: 2),
            VikunjaTask(id: 4, title: "Client B task", isDone: false, projectID: 3),
        ]
        let subprojects = [
            ProjectNode(project: Project(id: 2, title: "Client A", parentProjectID: 1)),
            ProjectNode(project: Project(id: 3, title: "Client B", parentProjectID: 1)),
        ]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            subprojects: subprojects,
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.subprojectTaskSummaries[2] == .init(done: 1, total: 2))
        #expect(viewModel.subprojectTaskSummaries[3] == .init(done: 0, total: 1))
    }

    @Test
    func loadOmitsASubprojectSummaryWhenItsFetchFails() async {
        let repository = FakeTaskRepository()
        repository.fetchError = .network("offline")
        let subprojects = [ProjectNode(project: Project(id: 2, title: "Client A", parentProjectID: 1))]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            subprojects: subprojects,
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        // The main project's own fetch fails first (surfacing the load
        // error), so subproject summaries never even get requested here —
        // this just confirms a failed fetch doesn't crash or leave a
        // stale/partial summary.
        #expect(viewModel.subprojectTaskSummaries.isEmpty)
    }

    @Test
    func toggleDonePersistsTheFlippedStateThroughTheRepository() async {
        let repository = FakeTaskRepository()
        repository.tasks = [VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1)]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.load()

        await viewModel.toggleDone(viewModel.tasks[0])

        #expect(viewModel.tasks[0].isDone == true)
    }

    @Test
    func toggleDoneRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.tasks = [VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1)]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.load()
        repository.updateError = .network("offline")

        await viewModel.toggleDone(viewModel.tasks[0])

        #expect(viewModel.tasks[0].isDone == false)
    }

    @Test
    func deleteRemovesTheTaskAndShowsASuccessToast() async {
        let repository = FakeTaskRepository()
        repository.tasks = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Review PR", projectID: 1),
        ]
        let toastPresenter = FakeToastPresenter()
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        await viewModel.load()

        await viewModel.delete(viewModel.tasks[0])

        #expect(viewModel.tasks.map(\.id) == [2])
        #expect(toastPresenter.shownMessages.last?.style == .success)
    }

    @Test
    func deleteLeavesTheTaskInPlaceAndShowsAnErrorToastOnFailure() async {
        let repository = FakeTaskRepository()
        let task = VikunjaTask(id: 1, title: "Write report", projectID: 1)
        repository.tasks = [task]
        repository.deleteError = .network("offline")
        let toastPresenter = FakeToastPresenter()
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        await viewModel.load()

        await viewModel.delete(task)

        #expect(viewModel.tasks.map(\.id) == [1])
        #expect(toastPresenter.shownMessages.last?.style == .error)
    }

    @Test
    func moveUpdatesTheTasksProjectAndRemovesItFromTheLocalList() async {
        let repository = FakeTaskRepository()
        repository.tasks = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Review PR", projectID: 1),
        ]
        let toastPresenter = FakeToastPresenter()
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        await viewModel.load()
        let destination = Project(id: 2, title: "Personal")

        await viewModel.move(viewModel.tasks[0], to: destination)

        #expect(viewModel.tasks.map(\.id) == [2])
        #expect(repository.tasks.first { $0.id == 1 }?.projectID == 2)
        #expect(toastPresenter.shownMessages.last?.style == .success)
    }

    @Test
    func moveLeavesTheTaskInPlaceAndShowsAnErrorToastOnFailure() async {
        let repository = FakeTaskRepository()
        let task = VikunjaTask(id: 1, title: "Write report", projectID: 1)
        repository.tasks = [task]
        repository.updateError = .network("offline")
        let toastPresenter = FakeToastPresenter()
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: repository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        await viewModel.load()

        await viewModel.move(task, to: Project(id: 2, title: "Personal"))

        #expect(viewModel.tasks.map(\.id) == [1])
        #expect(toastPresenter.shownMessages.last?.style == .error)
    }

    @Test
    func moveProjectGroupsExcludesThisScreensOwnProject() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [
            Project(id: 1, title: "Work"),
            Project(id: 2, title: "Personal"),
            Project(id: 3, title: "Client A", parentProjectID: 2),
        ]
        let viewModel = ProjectOverviewViewModel(
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadMoveCandidates()

        #expect(viewModel.moveProjectGroups.map(\.root.id) == [2])
        #expect(viewModel.moveProjectGroups.first?.children.map(\.id) == [3])
    }
}
