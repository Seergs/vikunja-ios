@testable import Projects
import Testing
import VikunjaCore

@MainActor
struct CreateProjectViewModelTests {
    @Test
    func `starts with no title and cannot save`() {
        let viewModel = CreateProjectViewModel(
            repository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter(),
        )

        #expect(viewModel.title.isEmpty)
        #expect(viewModel.canSave == false)
    }

    @Test
    func `can save requires A non blank title`() {
        let viewModel = CreateProjectViewModel(
            repository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter(),
        )

        viewModel.title = "   "
        #expect(viewModel.canSave == false)

        viewModel.title = "Groceries"
        #expect(viewModel.canSave == true)
    }

    @Test
    func `save creates A trimmed top level project by default`() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )
        viewModel.title = "  Groceries  "

        let created = await viewModel.save()

        #expect(created?.title == "Groceries")
        #expect(created?.parentProjectID == nil)
        #expect(repository.createdProjects.map(\.title) == ["Groceries"])
        #expect(viewModel.isSaving == false)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test
    func `save creates A subproject when A parent ID was supplied`() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            parentProjectID: 7,
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )
        viewModel.title = "Invoices"

        let created = await viewModel.save()

        #expect(created?.parentProjectID == 7)
        #expect(repository.createdProjects.first?.parentProjectID == 7)
    }

    @Test
    func `parent project ID is editable after construction`() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )
        viewModel.title = "Invoices"
        viewModel.parentProjectID = 3

        let created = await viewModel.save()

        #expect(created?.parentProjectID == 3)
    }

    @Test
    func `save creates A project with the chosen color`() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )
        viewModel.title = "Groceries"
        viewModel.hexColor = "FF0000"

        let created = await viewModel.save()

        #expect(created?.hexColor == "FF0000")
    }

    @Test
    func `load populates non archived projects sorted by position`() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "Later", isArchived: false, position: 2),
            Project(id: 2, title: "Archived", isArchived: true, position: 0),
            Project(id: 3, title: "First", isArchived: false, position: 1),
        ]
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.projects.map(\.id) == [3, 1])
    }

    @Test
    func `project groups arranges top level projects with their direct children`() async {
        let repository = FakeProjectRepository()
        repository.projects = [
            Project(id: 1, title: "Work", parentProjectID: nil, position: 0),
            Project(id: 2, title: "Redesign", parentProjectID: 1, position: 1),
            Project(id: 3, title: "Personal", parentProjectID: nil, position: 1),
            Project(id: 4, title: "Launch", parentProjectID: 1, position: 0),
        ]
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )

        await viewModel.load()

        #expect(viewModel.projectGroups.map(\.root.id) == [1, 3])
        #expect(viewModel.projectGroups[0].children.map(\.id) == [4, 2])
        #expect(viewModel.projectGroups[1].children.isEmpty)
    }

    @Test
    func `selected parent project resolves the chosen ID against the loaded projects`() async {
        let repository = FakeProjectRepository()
        repository.projects = [Project(id: 1, title: "Work")]
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )
        await viewModel.load()

        #expect(viewModel.selectedParentProject == nil)

        viewModel.parentProjectID = 1

        #expect(viewModel.selectedParentProject?.title == "Work")
    }

    @Test
    func `save shows A success toast`() async {
        let toastPresenter = FakeToastPresenter()
        let viewModel = CreateProjectViewModel(
            repository: FakeProjectRepository(),
            toastPresenter: toastPresenter,
        )
        viewModel.title = "Groceries"

        _ = await viewModel.save()

        #expect(toastPresenter.shownMessages.count == 1)
        #expect(toastPresenter.shownMessages.first?.message == "Project created")
        #expect(toastPresenter.shownMessages.first?.style == .success)
    }

    @Test
    func `save does nothing when the title is blank`() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )

        let created = await viewModel.save()

        #expect(created == nil)
        #expect(repository.createdProjects.isEmpty)
    }

    @Test
    func `save surfaces A friendly message on failure`() async {
        let repository = FakeProjectRepository()
        repository.createError = .network("offline")
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter(),
        )
        viewModel.title = "Groceries"

        let created = await viewModel.save()

        #expect(created == nil)
        #expect(viewModel.saveErrorMessage == "Couldn't reach that server. Check the address and your connection.")
        #expect(viewModel.isSaving == false)
    }
}
