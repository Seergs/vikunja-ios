import Foundation
import VikunjaCore
@testable import Onboarding

final class FakeAccountStore: AccountStoreProtocol, @unchecked Sendable {
    private(set) var accounts: [InstanceAccount] = []
    private(set) var tokens: [InstanceAccount.ID: String] = [:]
    private var activeID: InstanceAccount.ID?
    var addAccountCallCount = 0

    func fetchAccounts() async throws -> [InstanceAccount] { accounts }

    func activeAccount() async throws -> InstanceAccount? {
        accounts.first { $0.id == activeID }
    }

    func addAccount(_ account: InstanceAccount, token: String) async throws {
        addAccountCallCount += 1
        accounts.removeAll { $0.id == account.id }
        accounts.append(account)
        tokens[account.id] = token
        activeID = account.id
    }

    func updateAccount(_ account: InstanceAccount, token: String?) async throws {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            throw VikunjaError.notFound
        }
        accounts[index] = account
        if let token {
            tokens[account.id] = token
        }
    }

    func removeAccount(id: InstanceAccount.ID) async throws {
        accounts.removeAll { $0.id == id }
        tokens[id] = nil
    }

    func setActiveAccount(id: InstanceAccount.ID) async throws {
        activeID = id
    }

    func token(forAccountID id: InstanceAccount.ID) async throws -> String? {
        tokens[id]
    }
}

struct FakeCapabilityProvider: CapabilityProvider {
    var result: Result<VikunjaServerInfo, VikunjaError>

    func serverInfo() async throws -> VikunjaServerInfo {
        try result.get()
    }

    func supports(_ feature: VikunjaFeature) async -> Bool { false }
}

final class FakeInstanceClientFactory: InstanceClientFactoryProtocol, @unchecked Sendable {
    var result: Result<VikunjaServerInfo, VikunjaError> = .success(
        VikunjaServerInfo(version: "0.24.6", caldavEnabled: false, totpEnabled: false, registrationEnabled: false)
    )
    private(set) var requestedBaseURLs: [URL] = []

    func makeCapabilityProvider(baseURL: URL) -> CapabilityProvider {
        requestedBaseURLs.append(baseURL)
        return FakeCapabilityProvider(result: result)
    }

    func makeProjectRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> ProjectRepositoryProtocol {
        fatalError("not exercised by Onboarding tests")
    }

    func makeTaskRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskRepositoryProtocol {
        fatalError("not exercised by Onboarding tests")
    }

    func makeLabelRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> LabelRepositoryProtocol {
        fatalError("not exercised by Onboarding tests")
    }

    func makeTaskRelationRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskRelationRepositoryProtocol {
        fatalError("not exercised by Onboarding tests")
    }

    func makeTaskCommentRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskCommentRepositoryProtocol {
        fatalError("not exercised by Onboarding tests")
    }
}
