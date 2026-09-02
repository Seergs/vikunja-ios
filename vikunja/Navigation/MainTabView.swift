import Home
import Projects
import Search
import Settings
import SwiftUI
import Tasks
import VikunjaCore
import VikunjaDesignSystem
import VikunjaNavigation

/// The app's main navigation shell once a connection exists: a floating,
/// Liquid Glass tab bar (the default look for `TabView` on iOS 26+) with one
/// independent `NavigationStack` per tab, each owned by its own feature
/// module. `Search` uses iOS 26's dedicated `.search` tab role, which renders
/// it as a separated glass pill instead of grouping it with the others. The
/// quick-add button is a plain `.overlay`, not `.tabViewBottomAccessory` —
/// that API always paints a system glass background behind its content and
/// centers it over the tab bar, which can't be suppressed or anchored to a
/// corner, so it can't match the mockup's bare floating FAB.
struct MainTabView: View {
    let account: InstanceAccount
    let container: AppContainer
    /// Called after `Settings`' connection screens make a change that may
    /// have altered which account is active (switching, deleting the active
    /// one, or editing its own address) — `RootView` re-reads the active
    /// account and, since it renders this view keyed by `.id(connectedAccount)`,
    /// a changed value tears this whole tab shell down and rebuilds it against
    /// the new one. Dropping the last connection surfaces here too: the
    /// re-read comes back `nil` and `RootView` falls back to onboarding.
    let onAccountsChanged: () -> Void

    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                HomeRootView(
                    viewModel: container.makeTodayViewModel(account: account),
                    taskDetailDestination: taskDetailDestination,
                )
            }

            Tab(AppTab.projects.title, systemImage: AppTab.projects.systemImage, value: .projects) {
                ProjectsRootView(
                    viewModel: container.makeProjectsListViewModel(account: account),
                    makeOverviewViewModel: { node in
                        container.makeProjectOverviewViewModel(node: node, account: account)
                    },
                    makeCreateProjectViewModel: {
                        container.makeCreateProjectViewModel(account: account)
                    },
                    makeEditProjectViewModel: { project in
                        container.makeEditProjectViewModel(project: project, account: account)
                    },
                    taskDetailDestination: taskDetailDestination,
                )
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                SettingsRootView(
                    account: account,
                    makeConnectionsListViewModel: {
                        container.makeConnectionsListViewModel(onActiveAccountChanged: onAccountsChanged)
                    },
                    makeConnectionFormViewModel: { mode in
                        container.makeConnectionFormViewModel(mode: mode, onActiveAccountChanged: onAccountsChanged)
                    },
                    makeManageLabelsViewModel: {
                        container.makeManageLabelsViewModel(account: account)
                    },
                )
            }

            Tab(value: AppTab.search, role: .search) {
                SearchRootView(
                    viewModel: container.makeSearchViewModel(account: account),
                    onTaskSelected: taskDetailDestination,
                )
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(VikunjaColor.brandPrimary)
        // A light selection tick whenever the active tab changes — including a
        // programmatic switch from a `vikunja://` deep link. Doesn't fire on
        // first render, or on re-tapping the current tab (which pops to root
        // rather than changing `selection`).
        .vikunjaHaptic(.selection, trigger: selection)
        .overlay(alignment: .topTrailing) {
            if BuildConfig.isDevBuild {
                Text("DEV")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.orange, in: Circle())
                    .padding(VikunjaSpacing.md)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            QuickAddOverlay(container: container, account: account)
                .padding(.trailing, VikunjaSpacing.md)
                .padding(.bottom, VikunjaSpacing.xxl + VikunjaSpacing.lg)
        }
    }

    /// Builds a `Tasks.TaskDetailView` for the given task, type-erased so
    /// neither `Home` nor `Projects` needs to import `Tasks` directly — both
    /// tabs pass this same closure straight through as their own
    /// `taskDetailDestination`. Mutually recursive with `projectDestination`
    /// below: tapping a task's project pill pushes a project overview that
    /// can itself push back into a task's detail screen.
    private func taskDetailDestination(task: VikunjaTask, project: Project) -> AnyView {
        AnyView(
            TaskDetailView(
                viewModel: container.makeTaskDetailViewModel(task: task, project: project, account: account),
                projectDestination: projectDestination,
            ),
        )
    }

    /// Builds the `Projects.ProjectOverviewRootView` pushed when a task
    /// detail screen's project pill is tapped — `Features/Tasks` can't import
    /// `Projects` directly, so this closure (built here, where both are
    /// already imported) stands in for that push, the same way
    /// `taskDetailDestination` above stands in for `Projects`/`Home` pushing
    /// into `Tasks`.
    private func projectDestination(project: Project) -> AnyView {
        AnyView(
            ProjectOverviewRootView(
                viewModel: container.makeProjectOverviewViewModel(project: project, account: account),
                makeOverviewViewModel: { node in
                    container.makeProjectOverviewViewModel(node: node, account: account)
                },
                taskDetailDestination: taskDetailDestination,
            ),
        )
    }
}

/// The floating quick-add button and its sheet, split out of `MainTabView` so
/// that opening/closing the sheet — and snapshotting the quick-add project
/// context on tap — only re-evaluates this small view, never `MainTabView`'s
/// body. Left in `MainTabView`, that `@State` toggle rebuilt every tab's
/// `NavigationStack` and its view models on each open, blanking whatever
/// screen was behind the sheet.
private struct QuickAddOverlay: View {
    let container: AppContainer
    let account: InstanceAccount

    @State private var isShowingSheet = false
    /// Snapshot of `container.quickAddContext.preselectedProjectID` taken in
    /// the tap handler (not in `body`) so reading the `@Observable` context
    /// doesn't rebuild the sheet's view model whenever a project screen's
    /// scope enters or leaves the stack.
    @State private var preselectedProjectID: Int?

    var body: some View {
        QuickAddButton {
            preselectedProjectID = container.quickAddContext.preselectedProjectID
            isShowingSheet = true
        }
        .sheet(isPresented: $isShowingSheet) {
            QuickAddSheetView(
                viewModel: container.makeQuickAddTaskViewModel(
                    preselectedProjectID: preselectedProjectID,
                    account: account,
                ),
            )
        }
        // A `vikunja://quick-add` deep link opens the same sheet. Handled
        // here, not in `MainTabView`, so reading the router doesn't rebuild
        // every tab's `NavigationStack`. `.onChange` covers a link that
        // arrives while the shell is up; `.task` covers one already parked
        // on the router when this overlay mounts (cold launch).
        .onChange(of: container.deepLinkRouter.pending) { _, link in
            handleDeepLink(link)
        }
        .task {
            handleDeepLink(container.deepLinkRouter.pending)
        }
    }

    private func handleDeepLink(_ link: DeepLink?) {
        guard case let .quickAdd(projectID) = link else { return }
        preselectedProjectID = projectID ?? container.quickAddContext.preselectedProjectID
        isShowingSheet = true
        container.deepLinkRouter.clear()
    }
}
