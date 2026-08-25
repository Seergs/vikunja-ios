import Foundation
import Onboarding
import Projects
import Tasks
import VikunjaAuth
import VikunjaCore
import VikunjaNetworking

/// Composition root. The only type in the app target allowed to know about
/// concrete `VikunjaNetworking`/`VikunjaAuth` implementations — it wires them
/// into the `VikunjaCore` protocols each `Features/*` module receives through
/// constructor injection.
@MainActor
final class AppContainer {
    let accountStore: AccountStoreProtocol
    let clientFactory: InstanceClientFactoryProtocol

    init(
        accountStore: AccountStoreProtocol = KeychainAccountStore(),
        clientFactory: InstanceClientFactoryProtocol = VikunjaInstanceClientFactory()
    ) {
        self.accountStore = accountStore
        self.clientFactory = clientFactory
    }

    func makeInstanceSetupViewModel() -> InstanceSetupViewModel {
        InstanceSetupViewModel(accountStore: accountStore, clientFactory: clientFactory)
    }

    func makeProjectsListViewModel(account: InstanceAccount) -> ProjectsListViewModel {
        let accountStore = self.accountStore
        let repository = clientFactory.makeProjectRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return ProjectsListViewModel(repository: repository)
    }

    func makeProjectOverviewViewModel(node: ProjectNode, account: InstanceAccount) -> ProjectOverviewViewModel {
        let accountStore = self.accountStore
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return ProjectOverviewViewModel(project: node.project, subprojects: node.children, repository: repository)
    }

    func makeTaskDetailViewModel(task: VikunjaTask, account: InstanceAccount) -> TaskDetailViewModel {
        let accountStore = self.accountStore
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return TaskDetailViewModel(task: task, repository: repository)
    }
}
