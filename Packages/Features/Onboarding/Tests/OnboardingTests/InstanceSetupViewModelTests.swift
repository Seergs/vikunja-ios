import Foundation
@testable import Onboarding
import Testing
import VikunjaCore

@MainActor
struct InstanceSetupViewModelTests {
    private func makeViewModel(
        accountStore: FakeAccountStore = FakeAccountStore(),
        clientFactory: FakeInstanceClientFactory = FakeInstanceClientFactory(),
    ) -> InstanceSetupViewModel {
        InstanceSetupViewModel(accountStore: accountStore, clientFactory: clientFactory)
    }

    @Test
    func `can save is false until all fields are filled`() {
        let viewModel = makeViewModel()
        #expect(viewModel.canSave == false)

        viewModel.displayName = "Home"
        #expect(viewModel.canSave == false)

        viewModel.urlText = "tasks.example.com"
        #expect(viewModel.canSave == false)

        viewModel.apiToken = "a-token"
        #expect(viewModel.canSave == true)
    }

    @Test
    func `can save is false when fields are only whitespace`() {
        let viewModel = makeViewModel()
        viewModel.displayName = "   "
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        #expect(viewModel.canSave == false)
    }

    @Test
    func `saving A valid connection probes the normalized URL and persists the account`() async throws {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.validationState == .success)
        #expect(try clientFactory.requestedBaseURLs == [#require(URL(string: "https://tasks.example.com"))])
        #expect(accountStore.accounts.count == 1)
        #expect(accountStore.accounts.first?.displayName == "Home")
        #expect(accountStore.accounts.first?.baseURL == URL(string: "https://tasks.example.com")!)
        #expect(try accountStore.tokens[#require(accountStore.accounts.first?.id)] == "a-token")
    }

    @Test
    func `saving A valid connection exposes the saved account`() async {
        let viewModel = makeViewModel()
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"
        #expect(viewModel.savedAccount == nil)

        await viewModel.saveConnection()

        #expect(viewModel.savedAccount?.displayName == "Home")
    }

    @Test
    func `ing successfully does not expose A saved account`() async {
        let viewModel = makeViewModel()
        viewModel.urlText = "tasks.example.com"

        await viewModel.testConnection()

        #expect(viewModel.validationState == .success)
        #expect(viewModel.savedAccount == nil)
    }

    @Test
    func `saving clears the input fields on success`() async {
        let viewModel = makeViewModel()
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.displayName.isEmpty)
        #expect(viewModel.urlText.isEmpty)
        #expect(viewModel.apiToken.isEmpty)
    }

    @Test
    func `saving reloads the account list`() async {
        let viewModel = makeViewModel()
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.savedAccounts.count == 1)
        #expect(viewModel.savedAccounts.first?.displayName == "Home")
    }

    @Test
    func `saving an invalid URL fails without touching the account store`() async {
        let accountStore = FakeAccountStore()
        let viewModel = makeViewModel(accountStore: accountStore)
        viewModel.displayName = "Home"
        viewModel.urlText = "not a url"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.validationState == .failure("That doesn't look like a valid instance address."))
        #expect(accountStore.addAccountCallCount == 0)
    }

    @Test
    func `saving when the server probe fails surfaces A friendly message and does not persist`() async {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        clientFactory.result = .failure(.network("offline"))
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(
            viewModel.validationState == .failure("Couldn't reach that server. Check the address and your connection."),
        )
        #expect(accountStore.addAccountCallCount == 0)
    }

    @Test
    func `saving when not all fields are filled does nothing`() async {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.displayName = "Home"

        await viewModel.saveConnection()

        #expect(viewModel.validationState == .idle)
        #expect(accountStore.addAccountCallCount == 0)
        #expect(clientFactory.requestedBaseURLs.isEmpty)
    }

    @Test
    func `can test connection is false until an address is typed`() {
        let viewModel = makeViewModel()
        #expect(viewModel.canTestConnection == false)

        viewModel.urlText = "   "
        #expect(viewModel.canTestConnection == false)

        viewModel.urlText = "tasks.example.com"
        #expect(viewModel.canTestConnection == true)
    }

    @Test
    func `ing A valid address probes it without persisting an account`() async throws {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.urlText = "tasks.example.com"

        await viewModel.testConnection()

        #expect(viewModel.validationState == .success)
        #expect(try clientFactory.requestedBaseURLs == [#require(URL(string: "https://tasks.example.com"))])
        #expect(accountStore.addAccountCallCount == 0)
        #expect(viewModel.urlText == "tasks.example.com")
    }

    @Test
    func `ing when the server probe fails surfaces A friendly message`() async {
        let clientFactory = FakeInstanceClientFactory()
        clientFactory.result = .failure(.network("offline"))
        let viewModel = makeViewModel(clientFactory: clientFactory)
        viewModel.urlText = "tasks.example.com"

        await viewModel.testConnection()

        #expect(
            viewModel.validationState == .failure("Couldn't reach that server. Check the address and your connection."),
        )
    }

    @Test
    func `ing with no address does nothing`() async {
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(clientFactory: clientFactory)

        await viewModel.testConnection()

        #expect(viewModel.validationState == .idle)
        #expect(clientFactory.requestedBaseURLs.isEmpty)
    }

    @Test
    func `load saved accounts populates from the store`() async throws {
        let accountStore = FakeAccountStore()
        let existing = try InstanceAccount(displayName: "Work", baseURL: #require(URL(string: "https://work.example.com")))
        try? await accountStore.addAccount(existing, token: "work-token")
        let viewModel = makeViewModel(accountStore: accountStore)

        await viewModel.loadSavedAccounts()

        #expect(viewModel.savedAccounts == [existing])
    }
}
