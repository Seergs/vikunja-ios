import Foundation
import Testing
import VikunjaCore
@testable import Settings

@MainActor
struct ManageLabelsViewModelTests {
    private func makeViewModel(
        repository: FakeLabelRepository,
        toastPresenter: FakeToastPresenter = FakeToastPresenter()
    ) -> ManageLabelsViewModel {
        ManageLabelsViewModel(repository: repository, toastPresenter: toastPresenter)
    }

    @Test
    func loadPopulatesLabelsSortedByTitle() async {
        let repository = FakeLabelRepository(labels: [
            Label(id: 1, title: "Urgent", hexColor: "ff0000"),
            Label(id: 2, title: "backend", hexColor: "00ff00"),
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.labels.map(\.title) == ["backend", "Urgent"])
    }

    @Test
    func loadSurfacesAFriendlyMessageOnFailure() async {
        let repository = FakeLabelRepository()
        repository.fetchError = .network("offline")
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func createLabelAppendsTheServerAssignedLabel() async {
        let repository = FakeLabelRepository()
        let toast = FakeToastPresenter()
        let viewModel = makeViewModel(repository: repository, toastPresenter: toast)
        await viewModel.load()

        await viewModel.createLabel(title: "  Design  ", hexColor: "abcdef")

        #expect(viewModel.labels.count == 1)
        #expect(viewModel.labels.first?.title == "Design")
        #expect(viewModel.labels.first?.id == 1)
        #expect(toast.shownMessages.contains { $0.style == .success })
    }

    @Test
    func createLabelIgnoresABlankTitle() async {
        let repository = FakeLabelRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        await viewModel.createLabel(title: "   ", hexColor: "abcdef")

        #expect(viewModel.labels.isEmpty)
    }

    @Test
    func updateLabelRenamesAndRecolors() async {
        let repository = FakeLabelRepository(labels: [Label(id: 7, title: "old", hexColor: "000000")])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        await viewModel.updateLabel(viewModel.labels[0], title: "new", hexColor: "ffffff")

        #expect(viewModel.labels[0].title == "new")
        #expect(viewModel.labels[0].hexColor == "ffffff")
    }

    @Test
    func updateLabelRollsBackOnFailure() async {
        let original = Label(id: 7, title: "old", hexColor: "000000")
        let repository = FakeLabelRepository(labels: [original])
        repository.updateError = .server(message: "boom", statusCode: 500)
        let toast = FakeToastPresenter()
        let viewModel = makeViewModel(repository: repository, toastPresenter: toast)
        await viewModel.load()

        await viewModel.updateLabel(original, title: "new", hexColor: "ffffff")

        #expect(viewModel.labels == [original])
        #expect(toast.shownMessages.contains { $0.style == .error })
    }

    @Test
    func deleteLabelRemovesItOptimistically() async {
        let repository = FakeLabelRepository(labels: [
            Label(id: 1, title: "a", hexColor: "000000"),
            Label(id: 2, title: "b", hexColor: "000000"),
        ])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        await viewModel.deleteLabel(Label(id: 1, title: "a", hexColor: "000000"))

        #expect(viewModel.labels.map(\.id) == [2])
        #expect(repository.deletedIDs == [1])
    }

    @Test
    func deleteLabelRollsBackOnFailure() async {
        let labels = [
            Label(id: 1, title: "a", hexColor: "000000"),
            Label(id: 2, title: "b", hexColor: "000000"),
        ]
        let repository = FakeLabelRepository(labels: labels)
        repository.deleteError = .network("offline")
        let toast = FakeToastPresenter()
        let viewModel = makeViewModel(repository: repository, toastPresenter: toast)
        await viewModel.load()

        await viewModel.deleteLabel(labels[0])

        #expect(viewModel.labels.map(\.id) == [1, 2])
        #expect(toast.shownMessages.contains { $0.style == .error })
    }
}
