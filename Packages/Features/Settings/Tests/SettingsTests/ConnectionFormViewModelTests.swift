import Foundation
import Testing
import VikunjaCore
@testable import Settings

@MainActor
struct ConnectionFormViewModelTests {
    private func makeAccount(displayName: String = "Home", url: String = "https://tasks.example.com") -> InstanceAccount {
        InstanceAccount(displayName: displayName, baseURL: URL(string: url)!)
    }

    private func makeViewModel(
        mode: ConnectionFormMode,
        store: FakeAccountStore = FakeAccountStore(),
        factory: FakeInstanceClientFactory = FakeInstanceClientFactory(),
        toastPresenter: FakeToastPresenter = FakeToastPresenter(),
        onActiveAccountChanged: @escaping () -> Void = {}
    ) -> ConnectionFormViewModel {
        ConnectionFormViewModel(
            mode: mode,
            accountStore: store,
            clientFactory: factory,
            toastPresenter: toastPresenter,
            onActiveAccountChanged: onActiveAccountChanged
        )
    }

    // MARK: - create mode

    @Test
    func createModeStartsWithBlankFieldsAndCannotSave() {
        let viewModel = makeViewModel(mode: .create)

        #expect(viewModel.displayName.isEmpty)
        #expect(viewModel.urlText.isEmpty)
        #expect(viewModel.apiToken.isEmpty)
        #expect(viewModel.canSave == false)
        #expect(viewModel.isEditing == false)
    }

    @Test
    func savingInCreateModeProbesAndPersistsANewAccountAndNotifies() async throws {
        let store = FakeAccountStore()
        var notifiedCount = 0
        let toastPresenter = FakeToastPresenter()
        let viewModel = makeViewModel(mode: .create, store: store, toastPresenter: toastPresenter, onActiveAccountChanged: { notifiedCount += 1 })
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "secret"

        await viewModel.save()

        #expect(viewModel.validationState == .success)
        #expect(viewModel.savedAccount?.displayName == "Home")
        #expect(try await store.fetchAccounts().count == 1)
        #expect(try await store.activeAccount()?.displayName == "Home")
        #expect(notifiedCount == 1)
        #expect(toastPresenter.shownMessages.map(\.message) == ["Connection added"])
    }

    @Test
    func savingInCreateModeSurfacesAFriendlyMessageWhenTheProbeFails() async {
        let factory = FakeInstanceClientFactory()
        factory.result = .failure(.network("offline"))
        let viewModel = makeViewModel(mode: .create, factory: factory)
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "secret"

        await viewModel.save()

        #expect(viewModel.validationState == .failure("Couldn't reach that server. Check the address and your connection."))
        #expect(viewModel.savedAccount == nil)
    }

    // MARK: - edit mode

    @Test
    func editModePrefillsNameAndURLFromTheExistingAccount() {
        let account = makeAccount(displayName: "Home", url: "https://tasks.example.com")
        let viewModel = makeViewModel(mode: .edit(account))

        #expect(viewModel.displayName == "Home")
        #expect(viewModel.urlText == "https://tasks.example.com")
        #expect(viewModel.isEditing == true)
    }

    @Test
    func loadPrefillsTheExistingTokenInEditMode() async throws {
        let store = FakeAccountStore()
        let account = makeAccount()
        try await store.addAccount(account, token: "existing-token")
        let viewModel = makeViewModel(mode: .edit(account), store: store)

        await viewModel.load()

        #expect(viewModel.apiToken == "existing-token")
    }

    @Test
    func savingInEditModeUpdatesTheAccountWithoutChangingTheActivePointer() async throws {
        let store = FakeAccountStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")
        // `second` is active; edit `first`, the inactive one.
        var notifiedCount = 0
        let viewModel = makeViewModel(mode: .edit(first), store: store, onActiveAccountChanged: { notifiedCount += 1 })
        await viewModel.load()
        viewModel.displayName = "Renamed"

        await viewModel.save()

        #expect(viewModel.validationState == .success)
        #expect(try await store.fetchAccounts().first { $0.id == first.id }?.displayName == "Renamed")
        #expect(try await store.activeAccount() == second)
        // The active account's identity/shape didn't change, but the callback
        // still fires uniformly on every successful save — see the view
        // model's doc comment.
        #expect(notifiedCount == 1)
    }

    @Test
    func savingInEditModeRotatesTheTokenWhenChanged() async throws {
        let store = FakeAccountStore()
        let account = makeAccount()
        try await store.addAccount(account, token: "old-token")
        let viewModel = makeViewModel(mode: .edit(account), store: store)
        await viewModel.load()
        viewModel.apiToken = "new-token"

        await viewModel.save()

        #expect(try await store.token(forAccountID: account.id) == "new-token")
    }

    @Test
    func deleteConnectionRemovesTheAccountWhenAnotherOneExists() async throws {
        let store = FakeAccountStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")
        let viewModel = makeViewModel(mode: .edit(first), store: store)

        let didDelete = await viewModel.deleteConnection()

        #expect(didDelete == true)
        #expect(try await store.fetchAccounts().map(\.id) == [second.id])
    }

    @Test
    func deleteConnectionRefusesToRemoveTheLastAccount() async throws {
        let store = FakeAccountStore()
        let account = makeAccount()
        try await store.addAccount(account, token: "token")
        let toastPresenter = FakeToastPresenter()
        let viewModel = makeViewModel(mode: .edit(account), store: store, toastPresenter: toastPresenter)

        let didDelete = await viewModel.deleteConnection()

        #expect(didDelete == false)
        #expect(try await store.fetchAccounts() == [account])
        #expect(toastPresenter.shownMessages.map(\.message) == ["You need at least one connection"])
    }

    @Test
    func deleteConnectionNotifiesOnlyWhenTheDeletedAccountWasActive() async throws {
        let store = FakeAccountStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")
        // `second` is active.
        var notifiedCount = 0
        let viewModel = makeViewModel(mode: .edit(second), store: store, onActiveAccountChanged: { notifiedCount += 1 })

        _ = await viewModel.deleteConnection()

        #expect(notifiedCount == 1)
    }

    @Test
    func deleteConnectionIsANoOpInCreateMode() async {
        let viewModel = makeViewModel(mode: .create)

        let didDelete = await viewModel.deleteConnection()

        #expect(didDelete == false)
    }
}
