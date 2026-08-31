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
        let viewModel = TaskDetailViewModel(task: task, project: Project(id: 1, title: "Work"), repository: repository, labelRepository: FakeLabelRepository(), relationRepository: FakeTaskRelationRepository(), commentRepository: FakeTaskCommentRepository(), projectRepository: FakeProjectRepository(), toastPresenter: FakeToastPresenter())

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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
        let viewModel = TaskDetailViewModel(task: task, project: Project(id: 1, title: "Work"), repository: repository, labelRepository: FakeLabelRepository(), relationRepository: FakeTaskRelationRepository(), commentRepository: FakeTaskCommentRepository(), projectRepository: FakeProjectRepository(), toastPresenter: FakeToastPresenter())

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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.setPriority(.high)

        #expect(viewModel.task.priority == .unset)
    }

    @Test
    func setTitlePersistsTheNewTitle() async {
        let repository = FakeTaskRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.setTitle("Write annual report")

        #expect(viewModel.task.title == "Write annual report")
    }

    @Test
    func setTitleRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.updateError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.setTitle("Write annual report")

        #expect(viewModel.task.title == "Write report")
    }

    @Test
    func setDescriptionPersistsTheNewDescription() async {
        let repository = FakeTaskRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.setDescription("Quarterly numbers and highlights.")

        #expect(viewModel.task.description == "Quarterly numbers and highlights.")
    }

    @Test
    func setDescriptionRevertsWhenTheServerRejectsTheUpdate() async {
        let repository = FakeTaskRepository()
        repository.updateError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", description: "Original", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.setDescription("Changed")

        #expect(viewModel.task.description == "Original")
    }

    @Test
    func loadAllLabelsPopulatesFromTheRepository() async {
        let labelRepository = FakeLabelRepository()
        labelRepository.labels = [Label(id: 1, title: "Design", hexColor: "8B5CF6")]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: labelRepository,
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: labelRepository,
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: labelRepository,
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: labelRepository,
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: labelRepository,
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
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
            labelRepository: labelRepository,
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.createAndAddLabel(title: "Urgent", hexColor: "EF4444")

        #expect(viewModel.task.labels.isEmpty)
        #expect(viewModel.allLabels.isEmpty)
    }

    @Test
    func addRelationAppendsToTheNamedFieldForSubtaskDependsOnAndBlocks() async {
        let relationRepository = FakeTaskRelationRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: relationRepository,
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        let subtask = TaskRelation(id: 2, title: "Outline", projectID: 1)
        let dependency = TaskRelation(id: 3, title: "Approve brief", projectID: 1)
        let blocked = TaskRelation(id: 4, title: "Publish", projectID: 1)

        await viewModel.addRelation(subtask, kind: .subtask)
        await viewModel.addRelation(dependency, kind: .blocked)
        await viewModel.addRelation(blocked, kind: .blocking)

        #expect(viewModel.task.subtasks == [subtask])
        #expect(viewModel.task.dependsOn == [dependency])
        #expect(viewModel.task.blocks == [blocked])
        #expect(relationRepository.addedRelations.map(\.kind) == [.subtask, .blocked, .blocking])
        #expect(relationRepository.addedRelations.map(\.otherTaskID) == [2, 3, 4])
    }

    @Test
    func addRelationAppendsToOtherRelationsForEveryOtherKind() async {
        let relationRepository = FakeTaskRelationRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: relationRepository,
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        let related = TaskRelation(id: 6, title: "Related memo", projectID: 1)

        await viewModel.addRelation(related, kind: .related)

        #expect(viewModel.task.otherRelations[.related] == [related])
    }

    @Test
    func addRelationRevertsWhenTheServerRejectsIt() async {
        let relationRepository = FakeTaskRelationRepository()
        relationRepository.addError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: relationRepository,
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.addRelation(TaskRelation(id: 2, title: "Outline", projectID: 1), kind: .subtask)

        #expect(viewModel.task.subtasks.isEmpty)
    }

    @Test
    func addRelationShowsASuccessToast() async {
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        await viewModel.addRelation(TaskRelation(id: 2, title: "Outline", projectID: 1), kind: .subtask)

        #expect(toastPresenter.shownMessages.map(\.message) == ["Relation added"])
    }

    @Test
    func addRelationDoesNotShowAToastWhenTheServerRejectsIt() async {
        let relationRepository = FakeTaskRelationRepository()
        relationRepository.addError = .network("offline")
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: relationRepository,
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        await viewModel.addRelation(TaskRelation(id: 2, title: "Outline", projectID: 1), kind: .subtask)

        #expect(toastPresenter.shownMessages.isEmpty)
    }

    @Test
    func removeRelationDropsFromTheNamedFieldAndPersistsTheRemoval() async {
        let relationRepository = FakeTaskRelationRepository()
        let subtask = TaskRelation(id: 2, title: "Outline", projectID: 1)
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1, subtasks: [subtask]),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: relationRepository,
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.removeRelation(subtask, kind: .subtask)

        #expect(viewModel.task.subtasks.isEmpty)
        #expect(relationRepository.removedRelations.map(\.otherTaskID) == [2])
    }

    @Test
    func removeRelationRevertsWhenTheServerRejectsIt() async {
        let relationRepository = FakeTaskRelationRepository()
        relationRepository.removeError = .network("offline")
        let subtask = TaskRelation(id: 2, title: "Outline", projectID: 1)
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1, subtasks: [subtask]),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: relationRepository,
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.removeRelation(subtask, kind: .subtask)

        #expect(viewModel.task.subtasks == [subtask])
    }

    @Test
    func searchTasksForRelationExcludesTheTaskItselfAndAlreadyRelatedTasks() async {
        let repository = FakeTaskRepository()
        repository.searchResults = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Outline", projectID: 1),
            VikunjaTask(id: 3, title: "Approve brief", projectID: 1),
            VikunjaTask(id: 9, title: "Draft appendix", projectID: 1),
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(
                id: 1,
                title: "Write report",
                projectID: 1,
                subtasks: [TaskRelation(id: 2, title: "Outline", projectID: 1)],
                dependsOn: [TaskRelation(id: 3, title: "Approve brief", projectID: 1)]
            ),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.searchTasksForRelation(query: "a")

        #expect(viewModel.relationSearchResults.map(\.id) == [9])
    }

    @Test
    func searchTasksForRelationFallsBackToProjectSuggestionsForABlankQuery() async {
        let repository = FakeTaskRepository()
        repository.searchResults = [VikunjaTask(id: 9, title: "Draft appendix", projectID: 1)]
        repository.tasks = [VikunjaTask(id: 8, title: "Outline appendix", projectID: 1)]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.searchTasksForRelation(query: "   ")

        #expect(viewModel.relationSearchResults.map(\.id) == [8])
    }

    @Test
    func loadRelationSuggestionsPopulatesFromTheCurrentProjectExcludingSelfAndAlreadyRelatedTasks() async {
        let repository = FakeTaskRepository()
        repository.tasks = [
            VikunjaTask(id: 1, title: "Write report", projectID: 1),
            VikunjaTask(id: 2, title: "Outline", projectID: 1),
            VikunjaTask(id: 9, title: "Draft appendix", projectID: 1),
            VikunjaTask(id: 10, title: "Unrelated in another project", projectID: 2),
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(
                id: 1,
                title: "Write report",
                projectID: 1,
                subtasks: [TaskRelation(id: 2, title: "Outline", projectID: 1)]
            ),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadRelationSuggestions()

        #expect(viewModel.relationSearchResults.map(\.id) == [9])
    }

    @Test
    func searchTasksForRelationLeavesResultsEmptyOnFailure() async {
        let repository = FakeTaskRepository()
        repository.searchError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.searchTasksForRelation(query: "report")

        #expect(viewModel.relationSearchResults.isEmpty)
    }

    @Test
    func loadAllProjectsPopulatesFromTheRepository() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [Project(id: 2, title: "Personal"), Project(id: 3, title: "Health")]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadAllProjects()

        #expect(viewModel.allProjects == projectRepository.projects)
    }

    @Test
    func projectTitleResolvesTheCurrentProjectWithoutLoadingAllProjects() async {
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        #expect(viewModel.projectTitle(forProjectID: 1) == "Work")
    }

    @Test
    func projectTitleResolvesAnyLoadedProject() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [Project(id: 2, title: "Personal")]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadAllProjects()

        #expect(viewModel.projectTitle(forProjectID: 2) == "Personal")
        #expect(viewModel.projectTitle(forProjectID: 999) == nil)
    }

    @Test
    func loadCommentsPopulatesFromTheRepository() async {
        let commentRepository = FakeTaskCommentRepository()
        let author = User(id: 2, username: "sam", name: "Sam")
        commentRepository.comments = [
            TaskComment(id: 1, comment: "Looks good", author: author, created: Date(), updated: Date()),
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadComments()

        #expect(viewModel.comments == commentRepository.comments)
        #expect(viewModel.commentsLoadState == .loaded)
    }

    @Test
    func loadCommentsSurfacesAFriendlyMessageOnFailure() async {
        let commentRepository = FakeTaskCommentRepository()
        commentRepository.fetchError = .network("offline")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadComments()

        #expect(viewModel.commentsLoadState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func addCommentAppendsTheCreatedComment() async {
        let commentRepository = FakeTaskCommentRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.addComment("Sounds good")

        #expect(viewModel.comments.map(\.comment) == ["Sounds good"])
    }

    @Test
    func addCommentDoesNothingForBlankText() async {
        let commentRepository = FakeTaskCommentRepository()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.addComment("   ")

        #expect(viewModel.comments.isEmpty)
    }

    @Test
    func addCommentShowsAnErrorToastOnFailure() async {
        let commentRepository = FakeTaskCommentRepository()
        commentRepository.addError = .network("offline")
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        await viewModel.addComment("Sounds good")

        #expect(viewModel.comments.isEmpty)
        #expect(toastPresenter.shownMessages.map(\.style) == [.error])
    }

    @Test
    func deleteCommentRemovesItFromTheList() async {
        let commentRepository = FakeTaskCommentRepository()
        let author = User(id: 1, username: "me")
        commentRepository.comments = [
            TaskComment(id: 1, comment: "Keep", author: author, created: Date(), updated: Date()),
            TaskComment(id: 2, comment: "Drop", author: author, created: Date(), updated: Date())
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.loadComments()

        await viewModel.deleteComment(commentRepository.comments[1])

        #expect(viewModel.comments.map(\.id) == [1])
    }

    @Test
    func deleteCommentRestoresTheListAndShowsAnErrorToastOnFailure() async {
        let commentRepository = FakeTaskCommentRepository()
        commentRepository.deleteError = .network("offline")
        let author = User(id: 1, username: "me")
        let doomed = TaskComment(id: 2, comment: "Drop", author: author, created: Date(), updated: Date())
        commentRepository.comments = [
            TaskComment(id: 1, comment: "Keep", author: author, created: Date(), updated: Date()),
            doomed
        ]
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        await viewModel.loadComments()

        await viewModel.deleteComment(doomed)

        #expect(viewModel.comments.map(\.id) == [1, 2])
        #expect(toastPresenter.shownMessages.map(\.style) == [.error])
    }

    @Test
    func editCommentReplacesTheCommentWithTheServerResponse() async {
        let commentRepository = FakeTaskCommentRepository()
        let author = User(id: 1, username: "me")
        commentRepository.comments = [
            TaskComment(id: 1, comment: "Frist draft", author: author, created: Date(), updated: Date())
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.loadComments()

        await viewModel.editComment(viewModel.comments[0], newText: "  First draft  ")

        #expect(viewModel.comments.map(\.comment) == ["First draft"])
    }

    @Test
    func editCommentDoesNothingForBlankText() async {
        let commentRepository = FakeTaskCommentRepository()
        let author = User(id: 1, username: "me")
        commentRepository.comments = [
            TaskComment(id: 1, comment: "Original", author: author, created: Date(), updated: Date())
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )
        await viewModel.loadComments()

        await viewModel.editComment(viewModel.comments[0], newText: "   ")

        #expect(viewModel.comments.map(\.comment) == ["Original"])
    }

    @Test
    func editCommentKeepsTheOriginalAndShowsAnErrorToastOnFailure() async {
        let commentRepository = FakeTaskCommentRepository()
        commentRepository.updateError = .network("offline")
        let author = User(id: 1, username: "me")
        commentRepository.comments = [
            TaskComment(id: 1, comment: "Original", author: author, created: Date(), updated: Date())
        ]
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: commentRepository,
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        await viewModel.loadComments()

        await viewModel.editComment(viewModel.comments[0], newText: "Revised")

        #expect(viewModel.comments.map(\.comment) == ["Original"])
        #expect(toastPresenter.shownMessages.map(\.style) == [.error])
    }

    @Test
    func moveUpdatesTheTasksProjectAndShowsASuccessToast() async {
        let repository = FakeTaskRepository()
        repository.tasks = [VikunjaTask(id: 1, title: "Write report", projectID: 1)]
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        let succeeded = await viewModel.move(to: Project(id: 2, title: "Personal"))

        #expect(succeeded == true)
        #expect(viewModel.task.projectID == 2)
        #expect(toastPresenter.shownMessages.last?.style == .success)
    }

    @Test
    func moveRevertsAndShowsAnErrorToastOnFailure() async {
        let repository = FakeTaskRepository()
        repository.tasks = [VikunjaTask(id: 1, title: "Write report", projectID: 1)]
        repository.updateError = .network("offline")
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        let succeeded = await viewModel.move(to: Project(id: 2, title: "Personal"))

        #expect(succeeded == false)
        #expect(viewModel.task.projectID == 1)
        #expect(toastPresenter.shownMessages.last?.style == .error)
    }

    @Test
    func moveProjectGroupsExcludesTheTasksCurrentProject() async {
        let projectRepository = FakeProjectRepository()
        projectRepository.projects = [
            Project(id: 1, title: "Work"),
            Project(id: 2, title: "Personal"),
            Project(id: 3, title: "Client A", parentProjectID: 2),
        ]
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: projectRepository,
            toastPresenter: FakeToastPresenter()
        )

        await viewModel.loadAllProjects()

        #expect(viewModel.moveProjectGroups.map(\.root.id) == [2])
        #expect(viewModel.moveProjectGroups.first?.children.map(\.id) == [3])
    }

    @Test
    func deleteTaskShowsASuccessToast() async {
        let repository = FakeTaskRepository()
        repository.tasks = [VikunjaTask(id: 1, title: "Write report", projectID: 1)]
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        let succeeded = await viewModel.deleteTask()

        #expect(succeeded == true)
        #expect(toastPresenter.shownMessages.last?.style == .success)
    }

    @Test
    func deleteTaskShowsAnErrorToastOnFailure() async {
        let repository = FakeTaskRepository()
        repository.tasks = [VikunjaTask(id: 1, title: "Write report", projectID: 1)]
        repository.deleteError = .network("offline")
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: repository,
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )

        let succeeded = await viewModel.deleteTask()

        #expect(succeeded == false)
        #expect(toastPresenter.shownMessages.last?.style == .error)
    }

    @Test
    func isAssistantAvailableIsFalseWithoutAnAssistant() {
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        #expect(viewModel.isAssistantAvailable == false)
    }

    @Test
    func reviewWithAssistantStoresTheReviewForTheCurrentTask() async {
        let assistant = FakeTaskAssistant()
        assistant.result = "Add a due date and name the deliverable."
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter(),
            assistant: assistant
        )

        await viewModel.reviewWithAssistant()

        #expect(viewModel.assistantReview == "Add a due date and name the deliverable.")
        #expect(viewModel.isReviewing == false)
        #expect(assistant.reviewedTitles == ["Write report"])
    }

    @Test
    func unavailableAssistantExposesAReasonAndCannotRun() async {
        let assistant = FakeTaskAssistant()
        assistant.availability = .unavailable(reason: "Turn on Apple Intelligence in Settings to use this.")
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter(),
            assistant: assistant
        )

        #expect(viewModel.hasAssistant == true)
        #expect(viewModel.isAssistantAvailable == false)
        #expect(viewModel.assistantUnavailableReason == "Turn on Apple Intelligence in Settings to use this.")

        await viewModel.reviewWithAssistant()

        #expect(viewModel.assistantReview == nil)
        #expect(assistant.reviewedTitles.isEmpty)
    }

    @Test
    func reviewWithAssistantShowsAnErrorToastOnFailure() async {
        let assistant = FakeTaskAssistant()
        assistant.error = TaskAssistantError.unavailable
        let toastPresenter = FakeToastPresenter()
        let viewModel = TaskDetailViewModel(
            task: VikunjaTask(id: 1, title: "Write report", projectID: 1),
            project: Project(id: 1, title: "Work"),
            repository: FakeTaskRepository(),
            labelRepository: FakeLabelRepository(),
            relationRepository: FakeTaskRelationRepository(),
            commentRepository: FakeTaskCommentRepository(),
            projectRepository: FakeProjectRepository(),
            toastPresenter: toastPresenter,
            assistant: assistant
        )

        await viewModel.reviewWithAssistant()

        #expect(viewModel.assistantReview == nil)
        #expect(toastPresenter.shownMessages.last?.style == .error)
    }
}
