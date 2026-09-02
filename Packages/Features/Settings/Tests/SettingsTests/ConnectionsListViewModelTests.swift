import Foundation
@testable import Settings
import Testing
import VikunjaCore

@MainActor
struct ConnectionsListViewModelTests {
    private func makeAccount(displayName: String = "Home") -> InstanceAccount {
        InstanceAccount(displayName: displayName, baseURL: URL(string: "https://tasks.example.com")!)
    }

    private func makeViewModel(
        store: FakeAccountStore,
        toastPresenter: FakeToastPresenter = FakeToastPresenter(),
        onActiveAccountChanged: @escaping () -> Void = {},
    ) -> ConnectionsListViewModel {
        ConnectionsListViewModel(
            accountStore: store,
            toastPresenter: toastPresenter,
            onActiveAccountChanged: onActiveAccountChanged,
        )
    }

    @Test
    func `load populates accounts and the active ID`() async throws {
        let store = FakeAccountStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")
        let viewModel = makeViewModel(store: store)

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(Set(viewModel.accounts.map(\.id)) == Set([first.id, second.id]))
        #expect(viewModel.activeAccountID == second.id)
    }

    @Test
    func `load surfaces A friendly message on failure`() async {
        let store = FakeAccountStore()
        store.fetchAccountsError = .network("offline")
        let viewModel = makeViewModel(store: store)

        await viewModel.load()

        #expect(viewModel.loadState == .failure("Couldn't reach that server. Check the address and your connection."))
    }

    @Test
    func `set active switches the active account and notifies`() async throws {
        let store = FakeAccountStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")
        var notifiedCount = 0
        let viewModel = makeViewModel(store: store, onActiveAccountChanged: { notifiedCount += 1 })
        await viewModel.load()

        await viewModel.setActive(first)

        #expect(viewModel.activeAccountID == first.id)
        #expect(try await store.activeAccount() == first)
        #expect(notifiedCount == 1)
    }

    @Test
    func `set active on the already active account does nothing`() async throws {
        let store = FakeAccountStore()
        let account = makeAccount()
        try await store.addAccount(account, token: "token")
        var notifiedCount = 0
        let viewModel = makeViewModel(store: store, onActiveAccountChanged: { notifiedCount += 1 })
        await viewModel.load()

        await viewModel.setActive(account)

        #expect(notifiedCount == 0)
    }
}
