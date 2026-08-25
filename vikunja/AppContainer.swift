import Foundation
import Onboarding
import Projects
import Tasks
import VikunjaAuth
import VikunjaCore
import VikunjaDesignSystem
import VikunjaNetworking

/// Composition root. The only type in the app target allowed to know about
/// concrete `VikunjaNetworking`/`VikunjaAuth` implementations — it wires them
/// into the `VikunjaCore` protocols each `Features/*` module receives through
/// constructor injection.
@MainActor
final class AppContainer {
    let accountStore: AccountStoreProtocol
    let clientFactory: InstanceClientFactoryProtocol
    /// The single toast host for the whole app — see `RootView`'s
    /// `.toastHost(_:)`. Pass this as `ToastPresenting` to any ViewModel that
    /// needs to surface a toast (e.g. `toastPresenter:` in a `make...ViewModel`
    /// factory below); it never needs to import `VikunjaDesignSystem` itself.
    let toastCenter = ToastCenter()

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

    func makeTaskDetailViewModel(task: VikunjaTask, project: Project, account: InstanceAccount) -> TaskDetailViewModel {
        let accountStore = self.accountStore
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return TaskDetailViewModel(task: task, project: project, repository: repository)
    }

    func makeQuickAddTaskViewModel(account: InstanceAccount) -> QuickAddTaskViewModel {
        let accountStore = self.accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return QuickAddTaskViewModel(
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        )
    }
}
