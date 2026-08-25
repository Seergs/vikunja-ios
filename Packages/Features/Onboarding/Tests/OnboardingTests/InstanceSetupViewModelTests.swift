import Foundation
import Testing
import VikunjaCore
@testable import Onboarding

@MainActor
struct InstanceSetupViewModelTests {
    private func makeViewModel(
        accountStore: FakeAccountStore = FakeAccountStore(),
        clientFactory: FakeInstanceClientFactory = FakeInstanceClientFactory()
    ) -> InstanceSetupViewModel {
        InstanceSetupViewModel(accountStore: accountStore, clientFactory: clientFactory)
    }

    @Test
    func canSaveIsFalseUntilAllFieldsAreFilled() {
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
    func canSaveIsFalseWhenFieldsAreOnlyWhitespace() {
        let viewModel = makeViewModel()
        viewModel.displayName = "   "
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        #expect(viewModel.canSave == false)
    }

    @Test
    func savingAValidConnectionProbesTheNormalizedURLAndPersistsTheAccount() async {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.validationState == .success)
        #expect(clientFactory.requestedBaseURLs == [URL(string: "https://tasks.example.com")!])
        #expect(accountStore.accounts.count == 1)
        #expect(accountStore.accounts.first?.displayName == "Home")
        #expect(accountStore.accounts.first?.baseURL == URL(string: "https://tasks.example.com")!)
        #expect(accountStore.tokens[accountStore.accounts.first!.id] == "a-token")
    }

    @Test
    func savingClearsTheInputFieldsOnSuccess() async {
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
    func savingReloadsTheAccountList() async {
        let viewModel = makeViewModel()
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.savedAccounts.count == 1)
        #expect(viewModel.savedAccounts.first?.displayName == "Home")
    }

    @Test
    func savingAnInvalidURLFailsWithoutTouchingTheAccountStore() async {
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
    func savingWhenTheServerProbeFailsSurfacesAFriendlyMessageAndDoesNotPersist() async {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        clientFactory.result = .failure(.network("offline"))
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.displayName = "Home"
        viewModel.urlText = "tasks.example.com"
        viewModel.apiToken = "a-token"

        await viewModel.saveConnection()

        #expect(viewModel.validationState == .failure("Couldn't reach that server. Check the address and your connection."))
        #expect(accountStore.addAccountCallCount == 0)
    }

    @Test
    func savingWhenNotAllFieldsAreFilledDoesNothing() async {
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
    func canTestConnectionIsFalseUntilAnAddressIsTyped() {
        let viewModel = makeViewModel()
        #expect(viewModel.canTestConnection == false)

        viewModel.urlText = "   "
        #expect(viewModel.canTestConnection == false)

        viewModel.urlText = "tasks.example.com"
        #expect(viewModel.canTestConnection == true)
    }

    @Test
    func testingAValidAddressProbesItWithoutPersistingAnAccount() async {
        let accountStore = FakeAccountStore()
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(accountStore: accountStore, clientFactory: clientFactory)
        viewModel.urlText = "tasks.example.com"

        await viewModel.testConnection()

        #expect(viewModel.validationState == .success)
        #expect(clientFactory.requestedBaseURLs == [URL(string: "https://tasks.example.com")!])
        #expect(accountStore.addAccountCallCount == 0)
        #expect(viewModel.urlText == "tasks.example.com")
    }

    @Test
    func testingWhenTheServerProbeFailsSurfacesAFriendlyMessage() async {
        let clientFactory = FakeInstanceClientFactory()
        clientFactory.result = .failure(.network("offline"))
        let viewModel = makeViewModel(clientFactory: clientFactory)
        viewModel.urlText = "tasks.example.com"

        await viewModel.testConnection()

        #expect(viewModel.validationState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func testingWithNoAddressDoesNothing() async {
        let clientFactory = FakeInstanceClientFactory()
        let viewModel = makeViewModel(clientFactory: clientFactory)

        await viewModel.testConnection()

        #expect(viewModel.validationState == .idle)
        #expect(clientFactory.requestedBaseURLs.isEmpty)
    }

    @Test
    func loadSavedAccountsPopulatesFromTheStore() async {
        let accountStore = FakeAccountStore()
        let existing = InstanceAccount(displayName: "Work", baseURL: URL(string: "https://work.example.com")!)
        try? await accountStore.addAccount(existing, token: "work-token")
        let viewModel = makeViewModel(accountStore: accountStore)

        await viewModel.loadSavedAccounts()

        #expect(viewModel.savedAccounts == [existing])
    }
}
