import Testing
import VikunjaCore
@testable import Tasks

@MainActor
struct TaskDetailViewModelTests {
    @Test
    func startsWithTheTaskPassedInAtConstruction() {
        let repository = FakeTaskRepository()
        let task = VikunjaTask(id: 1, title: "Write report", projectID: 1)
        let viewModel = TaskDetailViewModel(task: task, project: Project(id: 1, title: "Work"), repository: repository)

        #expect(viewModel.task == task)
        #expect(viewModel.loadState == .idle)
    }

    @Test
    func loadReplacesTheTaskWithTheRepositorysFresherCopy() async {
        let repository = FakeTaskRepository()
        repository.tasks = [
            VikunjaTask(id: 1, title: "Write report", description: "Add the missing appendix", projectID: 1),
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.task.description == "Add the missing appendix")
    }

    @Test
    func loadSurfacesAFriendlyMessageOnFailure() async {
        let repository = FakeTaskRepository()
        repository.fetchError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func toggleDonePersistsTheFlippedStateThroughTheRepository() async {
        let repository = FakeTaskRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository
        )

        await viewModel.toggleDone()

        #expect(viewModel.task.isDone == true)
    }

    @Test
    func toggleDonePreservesRelationsTheUpdateResponseDoesntEcho() async {
        let repository = FakeTaskRepository()
        let task = VikunjaTask(
            id: 1,
            title: "Write report",
            isDone: false,
            projectID: 1,
            subtasks: [TaskRelation(id: 2, title: "Outline", isDone: true, projectID: 1)],
            dependsOn: [TaskRelation(id: 3, title: "Approve brief", isDone: false, projectID: 1)],
            blocks: [TaskRelation(id: 4, title: "Publish", isDone: false, projectID: 1)]
        )
        let viewModel = TaskDetailViewModel(task: task, project: Project(id: 1, title: "Work"), repository: repository)

        await viewModel.toggleDone()

        #expect(viewModel.task.isDone == true)
        #expect(viewModel.task.subtasks == task.subtasks)
        #expect(viewModel.task.dependsOn == task.dependsOn)
        #expect(viewModel.task.blocks == task.blocks)
    }

    @Test
    func toggleDoneRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.updateError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository
        )

        await viewModel.toggleDone()

        #expect(viewModel.task.isDone == false)
    }
}
