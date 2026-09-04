import CalendarFeature
import Foundation
import Home
import Onboarding
import Projects
import Search
import Settings
import Tasks
import VikuAuth
import VikuDesignSystem
import VikuNavigation
import VikunjaCore
import VikunjaNetworking
import VikuWidgetKit
import WidgetKit

/// Composition root. The only type in the app target allowed to know about
/// concrete `VikunjaNetworking`/`VikuAuth` implementations — it wires them
/// into the `VikunjaCore` protocols each `Features/*` module receives through
/// constructor injection.
@MainActor
final class AppContainer {
    let accountStore: AccountStoreProtocol
    let clientFactory: InstanceClientFactoryProtocol
    /// The single toast host for the whole app — see `RootView`'s
    /// `.toastHost(_:)`. Pass this as `ToastPresenting` to any ViewModel that
    /// needs to surface a toast (e.g. `toastPresenter:` in a `make...ViewModel`
    /// factory below); it never needs to import `VikuDesignSystem` itself.
    let toastCenter = ToastCenter()
    /// The app's single Taptic Engine — see `HapticFeedbackCenter`. Pass this
    /// as `HapticFeedbackPresenting` to any ViewModel that needs to fire a
    /// haptic from its own logic (e.g. add a `hapticPresenter:` parameter to
    /// the relevant `make...ViewModel` factory below, exactly like
    /// `toastPresenter:`); the ViewModel never imports `VikuDesignSystem`.
    /// A purely view-driven tap should use `View.vikuHaptic(_:trigger:)`
    /// instead and needs nothing from here.
    let hapticCenter = HapticFeedbackCenter()
    /// Tracks which project (if any) the visible screen represents, so the
    /// tab-bar quick-add sheet defaults to it — see `QuickAddContext`.
    let quickAddContext = QuickAddContext()
    /// The app's single theme preference (light/dark/automatic), read
    /// directly by `RootView` to drive `.preferredColorScheme(_:)` and passed
    /// to `Settings` as `AppThemeStoring` so it can offer the picker.
    let themeCenter = ThemeCenter()
    /// Carries a `viku://` deep link (or an `OpenQuickAddIntent`) from
    /// `RootView`'s `.onOpenURL` to the screen that acts on it. The shared
    /// instance, so the App Intent's `perform()` reaches the same router.
    let deepLinkRouter = DeepLinkRouter.shared
    /// On-device cache of each account's Vikunja default project, refreshed
    /// once per launch by `refreshDefaultProject(account:)` and read
    /// synchronously by `makeQuickAddTaskViewModel`.
    let defaultProjectStore = DefaultProjectStore()

    init(
        accountStore: AccountStoreProtocol = KeychainAccountStore(
            service: VikuWidgetConfig.accountStoreService,
            accessGroup: VikuWidgetConfig.keychainAccessGroup,
        ),
        clientFactory: InstanceClientFactoryProtocol = VikunjaInstanceClientFactory(),
    ) {
        self.accountStore = accountStore
        self.clientFactory = clientFactory
    }

    /// One-time move of Keychain items written before the shared
    /// `keychain-access-group` existed into that group, so the widget can read
    /// the active account and its token. No-op after the first run, and when
    /// `accountStore` isn't the Keychain-backed one (tests). Call once on launch.
    func bootstrap() async {
        guard let store = accountStore as? KeychainAccountStore else { return }
        try? await store.migrateToAccessGroup()
    }

    /// Fetches the Today and Calendar data with the app's own (always-working)
    /// account store and writes them to the shared App Group caches, then
    /// reloads every widget. This is what makes the widgets work even where
    /// keychain sharing with the extension doesn't (the iOS Simulator, an
    /// un-provisioned build): they render these caches when they can't
    /// authenticate themselves. Call on launch and whenever the app backgrounds.
    func refreshWidgetSnapshots() async {
        let todayLoader = TodaySnapshotLoader(
            accountStore: accountStore,
            clientFactory: clientFactory,
            cache: TodaySnapshotCache(appGroupIdentifier: VikuWidgetConfig.appGroupIdentifier),
        )
        let calendarLoader = CalendarSnapshotLoader(
            accountStore: accountStore,
            clientFactory: clientFactory,
            cache: CalendarSnapshotCache(appGroupIdentifier: VikuWidgetConfig.appGroupIdentifier),
        )
        _ = await todayLoader.loadState()
        _ = await calendarLoader.loadState()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Refreshes the cached Vikunja default project for `account` from
    /// `GET /api/v1/user` and writes it to `defaultProjectStore`. Called on
    /// launch and on account switch (see `RootView`) — the only place that
    /// request is made, so quick-add reads the cache instead of hitting the
    /// network every time its sheet opens. A failed fetch leaves the previous
    /// cached value untouched.
    func refreshDefaultProject(account: InstanceAccount) async {
        let accountStore = accountStore
        let userRepository = clientFactory.makeUserRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        guard let user = try? await userRepository.fetchCurrentUser() else { return }
        defaultProjectStore.setProjectID(user.defaultProjectID, forAccountID: account.id)
    }

    func makeInstanceSetupViewModel() -> InstanceSetupViewModel {
        InstanceSetupViewModel(accountStore: accountStore, clientFactory: clientFactory)
    }

    func makeTodayViewModel(account: InstanceAccount) -> TodayViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return TodayViewModel(
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(
                baseURL: account.baseURL,
                tokenProvider: tokenProvider,
            ),
            toastPresenter: toastCenter,
            hapticPresenter: hapticCenter,
        )
    }

    func makeCalendarViewModel(account: InstanceAccount) -> CalendarViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return CalendarViewModel(
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(
                baseURL: account.baseURL,
                tokenProvider: tokenProvider,
            ),
            hapticPresenter: hapticCenter,
        )
    }

    func makeProjectsListViewModel(account: InstanceAccount) -> ProjectsListViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        let repository = clientFactory.makeProjectRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let taskRepository = clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        return ProjectsListViewModel(
            repository: repository,
            taskRepository: taskRepository,
            toastPresenter: toastCenter,
        )
    }

    func makeCreateProjectViewModel(parentProjectID: Int? = nil, account: InstanceAccount) -> CreateProjectViewModel {
        let accountStore = accountStore
        let repository = clientFactory.makeProjectRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return CreateProjectViewModel(
            parentProjectID: parentProjectID,
            repository: repository,
            toastPresenter: toastCenter,
        )
    }

    func makeEditProjectViewModel(project: Project, account: InstanceAccount) -> EditProjectViewModel {
        let accountStore = accountStore
        let repository = clientFactory.makeProjectRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return EditProjectViewModel(project: project, repository: repository, toastPresenter: toastCenter)
    }

    func makeProjectOverviewViewModel(node: ProjectNode, account: InstanceAccount) -> ProjectOverviewViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let projectRepository = clientFactory.makeProjectRepository(
            baseURL: account.baseURL,
            tokenProvider: tokenProvider,
        )
        return ProjectOverviewViewModel(
            project: node.project,
            subprojects: node.children,
            repository: repository,
            projectRepository: projectRepository,
            toastPresenter: toastCenter,
            hapticPresenter: hapticCenter,
            quickAddContext: quickAddContext,
        )
    }

    /// For a project reached from outside the already-loaded projects tree
    /// (`Features/Tasks`' project pill, today) — see `ProjectOverviewRootView`.
    /// No `ProjectNode` is available there, only the bare `Project`, so this
    /// seeds `ProjectOverviewViewModel` with no known subprojects.
    func makeProjectOverviewViewModel(project: Project, account: InstanceAccount) -> ProjectOverviewViewModel {
        makeProjectOverviewViewModel(node: ProjectNode(project: project), account: account)
    }

    func makeTaskDetailViewModel(task: VikunjaTask, project: Project, account: InstanceAccount) -> TaskDetailViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        let repository = clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let labelRepository = clientFactory.makeLabelRepository(baseURL: account.baseURL, tokenProvider: tokenProvider)
        let relationRepository = clientFactory.makeTaskRelationRepository(
            baseURL: account.baseURL,
            tokenProvider: tokenProvider,
        )
        let commentRepository = clientFactory.makeTaskCommentRepository(
            baseURL: account.baseURL,
            tokenProvider: tokenProvider,
        )
        let attachmentRepository = clientFactory.makeTaskAttachmentRepository(
            baseURL: account.baseURL,
            tokenProvider: tokenProvider,
        )
        let projectRepository = clientFactory.makeProjectRepository(
            baseURL: account.baseURL,
            tokenProvider: tokenProvider,
        )
        return TaskDetailViewModel(
            task: task,
            project: project,
            repository: repository,
            labelRepository: labelRepository,
            relationRepository: relationRepository,
            commentRepository: commentRepository,
            attachmentRepository: attachmentRepository,
            projectRepository: projectRepository,
            toastPresenter: toastCenter,
            hapticPresenter: hapticCenter,
            quickAddContext: quickAddContext,
        )
    }

    /// - Parameter preselectedProjectID: snapshotted by the caller (see
    ///   `MainTabView`) at the moment the quick-add sheet is opened — not read
    ///   from `quickAddContext` here, since this factory runs inside a
    ///   SwiftUI view body and an `@Observable` read would rebuild the sheet.
    func makeQuickAddTaskViewModel(
        preselectedProjectID: Int?,
        account: InstanceAccount,
    ) -> QuickAddTaskViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return QuickAddTaskViewModel(
            preselectedProjectID: preselectedProjectID,
            accountDefaultProjectID: defaultProjectStore.projectID(forAccountID: account.id),
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(
                baseURL: account.baseURL,
                tokenProvider: tokenProvider,
            ),
            toastPresenter: toastCenter,
        )
    }

    func makeManageLabelsViewModel(account: InstanceAccount) -> ManageLabelsViewModel {
        let accountStore = accountStore
        let repository = clientFactory.makeLabelRepository(baseURL: account.baseURL) {
            try? await accountStore.token(forAccountID: account.id)
        }
        return ManageLabelsViewModel(repository: repository, toastPresenter: toastCenter)
    }

    func makeConnectionsListViewModel(onActiveAccountChanged: @escaping () -> Void) -> ConnectionsListViewModel {
        ConnectionsListViewModel(
            accountStore: accountStore,
            clientFactory: clientFactory,
            toastPresenter: toastCenter,
            onActiveAccountChanged: onActiveAccountChanged,
        )
    }

    func makeConnectionFormViewModel(
        mode: ConnectionFormMode,
        onActiveAccountChanged: @escaping () -> Void,
    ) -> ConnectionFormViewModel {
        ConnectionFormViewModel(
            mode: mode,
            accountStore: accountStore,
            clientFactory: clientFactory,
            toastPresenter: toastCenter,
            onActiveAccountChanged: onActiveAccountChanged,
        )
    }

    func makeSearchViewModel(account: InstanceAccount) -> SearchViewModel {
        let accountStore = accountStore
        let tokenProvider: @Sendable () async -> String? = {
            try? await accountStore.token(forAccountID: account.id)
        }
        return SearchViewModel(
            taskRepository: clientFactory.makeTaskRepository(baseURL: account.baseURL, tokenProvider: tokenProvider),
            projectRepository: clientFactory.makeProjectRepository(
                baseURL: account.baseURL,
                tokenProvider: tokenProvider,
            ),
            toastPresenter: toastCenter,
            hapticPresenter: hapticCenter,
        )
    }
}
