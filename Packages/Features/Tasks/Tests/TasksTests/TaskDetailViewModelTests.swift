import Foundation
import Testing
import VikunjaCore
@testable import Tasks

@MainActor
struct TaskDetailViewModelTests {
    @Test
    func startsWithTheTaskPassedInAtConstruction() {
        let repository = FakeTaskRepository()
        let task = VikunjaTask(id: 1, title: "Write report", projectID: 1)
        let viewModel = TaskDetailViewModel(task: task, project: Project(id: 1, title: "Work"), repository: repository, labelRepository: FakeLabelRepository())

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
            repository: repository,
            labelRepository: FakeLabelRepository()
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
            repository: repository,
            labelRepository: FakeLabelRepository()
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
            repository: repository,
            labelRepository: FakeLabelRepository()
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
            blocks: [TaskRelation(id: 4, title: "Publish", isDone: false, projectID: 1)],
            otherRelations: [.related: [TaskRelation(id: 5, title: "Related memo", isDone: false, projectID: 1)]]
        )
        let viewModel = TaskDetailViewModel(task: task, project: Project(id: 1, title: "Work"), repository: repository, labelRepository: FakeLabelRepository())

        await viewModel.toggleDone()

        #expect(viewModel.task.isDone == true)
        #expect(viewModel.task.subtasks == task.subtasks)
        #expect(viewModel.task.dependsOn == task.dependsOn)
        #expect(viewModel.task.blocks == task.blocks)
        #expect(viewModel.task.otherRelations == task.otherRelations)
    }

    @Test
    func toggleDoneRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.updateError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", isDone: false, projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository()
        )

        await viewModel.toggleDone()

        #expect(viewModel.task.isDone == false)
    }

    @Test
    func setDueDatePersistsTheChosenDate() async {
        let repository = FakeTaskRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository()
        )
        let dueDate = Date(timeIntervalSince1970: 1_700_000_000)

        await viewModel.setDueDate(dueDate)

        #expect(viewModel.task.dueDate == dueDate)
    }

    @Test
    func setDueDateRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.updateError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository()
        )

        await viewModel.setDueDate(Date())

        #expect(viewModel.task.dueDate == nil)
    }

    @Test
    func setPriorityPersistsTheChosenPriority() async {
        let repository = FakeTaskRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository()
        )

        await viewModel.setPriority(.urgent)

        #expect(viewModel.task.priority == .urgent)
    }

    @Test
    func setPriorityRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.updateError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository()
        )

        await viewModel.setPriority(.high)

        #expect(viewModel.task.priority == .unset)
    }

    @Test
    func loadAllLabelsPopulatesFromTheRepository() async {
        let labelRepository = FakeLabelRepository()
        labelRepository.labels = [Label(id: 1, title: "Design", hexColor: "8B5CF6")]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository
        )

        await viewModel.loadAllLabels()

        #expect(viewModel.allLabels == labelRepository.labels)
    }

    @Test
    func toggleLabelAddsAnUnattachedLabelAndPersistsTheAssociation() async {
        let labelRepository = FakeLabelRepository()
        let label = Label(id: 1, title: "Design", hexColor: "8B5CF6")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository
        )

        await viewModel.toggleLabel(label)

        #expect(viewModel.task.labels == [label])
        #expect(labelRepository.addedLabelIDs.map(\.labelID) == [1])
    }

    @Test
    func toggleLabelRemovesAnAttachedLabelAndPersistsTheAssociation() async {
        let labelRepository = FakeLabelRepository()
        let label = Label(id: 1, title: "Design", hexColor: "8B5CF6")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1, labels: [label]),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository
        )

        await viewModel.toggleLabel(label)

        #expect(viewModel.task.labels.isEmpty)
        #expect(labelRepository.removedLabelIDs.map(\.labelID) == [1])
    }

    @Test
    func toggleLabelRevertsWhenTheServerRejectsTheAssociation() async {
        let labelRepository = FakeLabelRepository()
        labelRepository.addError = .network("offline")
        let label = Label(id: 1, title: "Design", hexColor: "8B5CF6")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository
        )

        await viewModel.toggleLabel(label)

        #expect(viewModel.task.labels.isEmpty)
    }

    @Test
    func createAndAddLabelCreatesThenAttachesTheNewLabel() async {
        let labelRepository = FakeLabelRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository
        )

        await viewModel.createAndAddLabel(title: "Urgent", hexColor: "EF4444")

        #expect(viewModel.task.labels.map(\.title) == ["Urgent"])
        #expect(viewModel.allLabels.map(\.title) == ["Urgent"])
        #expect(labelRepository.addedLabelIDs.count == 1)
    }

    @Test
    func createAndAddLabelDoesNothingWhenCreationFails() async {
        let labelRepository = FakeLabelRepository()
        labelRepository.createError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository
        )

        await viewModel.createAndAddLabel(title: "Urgent", hexColor: "EF4444")

        #expect(viewModel.task.labels.isEmpty)
        #expect(viewModel.allLabels.isEmpty)
    }
}
