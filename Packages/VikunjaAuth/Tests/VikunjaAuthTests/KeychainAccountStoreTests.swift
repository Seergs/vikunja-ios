import Foundation
import Testing
import VikunjaCore
@testable import VikunjaAuth

// Exercises the real Keychain (generic password items), so this suite runs
// serialized against a service namespace unique to the test process to avoid
// clobbering state across parallel test runs.
@Suite(.serialized)
struct KeychainAccountStoreTests {
    private func makeStore() -> KeychainAccountStore {
        KeychainAccountStore(service: "dev.sergiosuarez.vikunja.tests.\(UUID().uuidString)")
    }

    private func makeAccount(displayName: String = "Home") -> InstanceAccount {
        InstanceAccount(displayName: displayName, baseURL: URL(string: "https://tasks.example.com")!)
    }

    @Test
    func startsWithNoAccounts() async throws {
        let store = makeStore()

        #expect(try await store.fetchAccounts().isEmpty)
        #expect(try await store.activeAccount() == nil)
    }

    @Test
    func addingAnAccountPersistsItAndItsTokenAndMakesItActive() async throws {
        let store = makeStore()
        let account = makeAccount()

        try await store.addAccount(account, token: "secret-token")

        #expect(try await store.fetchAccounts() == [account])
        #expect(try await store.activeAccount() == account)
        #expect(try await store.token(forAccountID: account.id) == "secret-token")
    }

    @Test
    func addingASecondAccountMakesItTheActiveOneWithoutLosingTheFirst() async throws {
        let store = makeStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")

        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")

        #expect(Set(try await store.fetchAccounts().map(\.id)) == Set([first.id, second.id]))
        #expect(try await store.activeAccount() == second)
        #expect(try await store.token(forAccountID: first.id) == "first-token")
    }

    @Test
    func setActiveAccountSwitchesTheActivePointer() async throws {
        let store = makeStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")

        try await store.setActiveAccount(id: first.id)

        #expect(try await store.activeAccount() == first)
    }

    @Test
    func setActiveAccountThrowsForAnUnknownID() async throws {
        let store = makeStore()

        await #expect(throws: VikunjaError.notFound) {
            try await store.setActiveAccount(id: UUID())
        }
    }

    @Test
    func updatingAnAccountChangesItsMetadataWithoutTouchingTheActivePointer() async throws {
        let store = makeStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")
        try await store.setActiveAccount(id: first.id)

        var renamed = second
        renamed.displayName = "Office"
        try await store.updateAccount(renamed, token: nil)

        #expect(try await store.fetchAccounts().contains(renamed))
        #expect(try await store.activeAccount() == first)
        #expect(try await store.token(forAccountID: second.id) == "second-token")
    }

    @Test
    func updatingAnAccountWithATokenRotatesTheStoredCredential() async throws {
        let store = makeStore()
        let account = makeAccount()
        try await store.addAccount(account, token: "old-token")

        try await store.updateAccount(account, token: "new-token")

        #expect(try await store.token(forAccountID: account.id) == "new-token")
    }

    @Test
    func updatingAnUnknownAccountThrows() async throws {
        let store = makeStore()

        await #expect(throws: VikunjaError.notFound) {
            try await store.updateAccount(makeAccount(), token: nil)
        }
    }

    @Test
    func removingTheActiveAccountPromotesAnotherOne() async throws {
        let store = makeStore()
        let first = makeAccount(displayName: "Home")
        let second = makeAccount(displayName: "Work")
        try await store.addAccount(first, token: "first-token")
        try await store.addAccount(second, token: "second-token")

        try await store.removeAccount(id: second.id)

        #expect(try await store.fetchAccounts() == [first])
        #expect(try await store.activeAccount() == first)
        #expect(try await store.token(forAccountID: second.id) == nil)
    }

    @Test
    func removingTheLastAccountLeavesNoActiveAccount() async throws {
        let store = makeStore()
        let account = makeAccount()
        try await store.addAccount(account, token: "secret-token")

        try await store.removeAccount(id: account.id)

        #expect(try await store.fetchAccounts().isEmpty)
        #expect(try await store.activeAccount() == nil)
    }
}
