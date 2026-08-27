import Foundation
import Home
import Onboarding
import Projects
import Settings
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

    func makeTodayViewModel(account: InstanceAccount) -> TodayViewModel {
        let accountStore = self.accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return TodayViewModel(
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            toastPresenter: toastCenter
        )
    }

    func makeProjectsListViewModel(account: InstanceAccount) -> ProjectsListViewModel {
        let accountStore = self.accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        let repository = clientFactory.makeProjectRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let taskRepository = clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        return ProjectsListViewModel(repository: repository, taskRepository: taskRepository)
    }

    func makeCreateProjectViewModel(parentProjectID: Int? = nil, account: InstanceAccount) -> CreateProjectViewModel {
        let accountStore = self.accountStore
        let repository = clientFactory.makeProjectRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return CreateProjectViewModel(parentProjectID: parentProjectID, repository: repository, toastPresenter: toastCenter)
    }

    func makeProjectOverviewViewModel(node: ProjectNode, account: InstanceAccount) -> ProjectOverviewViewModel {
        let accountStore = self.accountStore
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return ProjectOverviewViewModel(
            project: node.project,
            subprojects: node.children,
            repository: repository,
            toastPresenter: toastCenter
        )
    }

    func makeTaskDetailViewModel(task: VikunjaTask, project: Project, account: InstanceAccount) -> TaskDetailViewModel {
        let accountStore = self.accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let labelRepository = clientFactory.makeLabelRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let relationRepository = clientFactory.makeTaskRelationRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let commentRepository = clientFactory.makeTaskCommentRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let projectRepository = clientFactory.makeProjectRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        return TaskDetailViewModel(
            task: task,
            project: project,
            repository: repository,
            labelRepository: labelRepository,
            relationRepository: relationRepository,
            commentRepository: commentRepository,
            projectRepository: projectRepository,
            toastPresenter: toastCenter
        )
    }

    func makeQuickAddTaskViewModel(account: InstanceAccount) -> QuickAddTaskViewModel {
        let accountStore = self.accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return QuickAddTaskViewModel(
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            toastPresenter: toastCenter
        )
    }

    func makeConnectionsListViewModel(onActiveAccountChanged: @escaping () -> Void) -> ConnectionsListViewModel {
        ConnectionsListViewModel(accountStore: accountStore, toastPresenter: toastCenter, onActiveAccountChanged: onActiveAccountChanged)
    }

    func makeConnectionFormViewModel(
        mode: ConnectionFormMode,
        onActiveAccountChanged: @escaping () -> Void
    ) -> ConnectionFormViewModel {
        ConnectionFormViewModel(
            mode: mode,
            accountStore: accountStore,
            clientFactory: clientFactory,
            toastPresenter: toastCenter,
            onActiveAccountChanged: onActiveAccountChanged
        )
    }
}
