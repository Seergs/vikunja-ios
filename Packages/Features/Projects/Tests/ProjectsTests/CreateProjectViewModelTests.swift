import Testing
import VikunjaCore
@testable import Projects

@MainActor
struct CreateProjectViewModelTests {
    @Test
    func startsWithNoTitleAndCannotSave() {
        let viewModel = CreateProjectViewModel(
            repository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        #expect(viewModel.title.isEmpty)
        #expect(viewModel.canSave == false)
    }

    @Test
    func canSaveRequiresANonBlankTitle() {
        let viewModel = CreateProjectViewModel(
            repository: FakeProjectRepository(),
            toastPresenter: FakeToastPresenter()
        )

        viewModel.title = "   "
        #expect(viewModel.canSave == false)

        viewModel.title = "Groceries"
        #expect(viewModel.canSave == true)
    }

    @Test
    func saveCreatesATrimmedTopLevelProjectByDefault() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter()
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
    func saveCreatesASubprojectWhenAParentIDWasSupplied() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            parentProjectID: 7,
            repository: repository,
            toastPresenter: FakeToastPresenter()
        )
        viewModel.title = "Invoices"

        let created = await viewModel.save()

        #expect(created?.parentProjectID == 7)
        #expect(repository.createdProjects.first?.parentProjectID == 7)
    }

    @Test
    func saveShowsASuccessToast() async {
        let toastPresenter = FakeToastPresenter()
        let viewModel = CreateProjectViewModel(
            repository: FakeProjectRepository(),
            toastPresenter: toastPresenter
        )
        viewModel.title = "Groceries"

        _ = await viewModel.save()

        #expect(toastPresenter.shownMessages.count == 1)
        #expect(toastPresenter.shownMessages.first?.message == "Project created")
        #expect(toastPresenter.shownMessages.first?.style == .success)
    }

    @Test
    func saveDoesNothingWhenTheTitleIsBlank() async {
        let repository = FakeProjectRepository()
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter()
        )

        let created = await viewModel.save()

        #expect(created == nil)
        #expect(repository.createdProjects.isEmpty)
    }

    @Test
    func saveSurfacesAFriendlyMessageOnFailure() async {
        let repository = FakeProjectRepository()
        repository.createError = .network("offline")
        let viewModel = CreateProjectViewModel(
            repository: repository,
            toastPresenter: FakeToastPresenter()
        )
        viewModel.title = "Groceries"

        let created = await viewModel.save()

        #expect(created == nil)
        #expect(viewModel.saveErrorMessage == "Couldn't reach that server. Check the address and your connection.")
        #expect(viewModel.isSaving == false)
    }
}
