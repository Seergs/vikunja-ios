import Testing
import VikunjaCore
@testable import Home

@MainActor
struct TodayViewModelTests {
    @Test
    func loadMergesTasksAcrossEveryProject() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [
            Project(id: 1, title: "Work"),
            Project(id: 2, title: "Personal"),
        ]
        let taskRepository = FakeTaskRepository()
        taskRepository.tasks = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Buy groceries", projectID: 2),
        ]
        let viewModel = TodayViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(Set(viewModel.tasks.map(\.id)) == [1, 2])
        #expect(viewModel.projectsByID[1]?.title == "Work")
        #expect(viewModel.projectsByID[2]?.title == "Personal")
    }

    @Test
    func loadDropsATaskListWhoseProjectFetchFails() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [
            Project(id: 1, title: "Work"),
            Project(id: 2, title: "Personal"),
        ]
        let taskRepository = FakeTaskRepository()
        taskRepository.tasks = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Buy groceries", projectID: 2),
        ]
        taskRepository.failingProjectIDs = [2]
        let viewModel = TodayViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.tasks.map(\.id) == [1])
    }

    @Test
    func loadSurfacesAFriendlyMessageWhenFetchingProjectsFails() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.fetchError = .network("offline")
        let viewModel = TodayViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
        #expect(viewModel.tasks.isEmpty)
    }

    @Test
    func toggleDonePersistsTheFlippedStateThroughTheRepository() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [Project(id: 1, title: "Work")]
        let taskRepository = FakeTaskRepository()
        taskRepository.tasks = [VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1)]
        let viewModel = TodayViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.load()

        await viewModel.toggleDone(viewModel.tasks[0])

        #expect(viewModel.tasks[0].isDone == true)
    }

    @Test
    func toggleDoneRevertsWhenTheServerRejectsTheUpdate() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [Project(id: 1, title: "Work")]
        let taskRepository = FakeTaskRepository()
        taskRepository.tasks = [VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1)]
        let viewModel = TodayViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.load()
        taskRepository.updateError = .network("offline")

        await viewModel.toggleDone(viewModel.tasks[0])

        #expect(viewModel.tasks[0].isDone == false)
    }
}
