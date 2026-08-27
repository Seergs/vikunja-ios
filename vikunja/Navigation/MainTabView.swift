import Home
import Projects
import Search
import Settings
import SwiftUI
import Tasks
import VikunjaCore
import VikunjaDesignSystem

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
    @State private var isShowingQuickAdd = false

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                HomeRootView(
                    viewModel: container.makeTodayViewModel(account: account),
                    taskDetailDestination: { task, project in
                        AnyView(TaskDetailView(viewModel: container.makeTaskDetailViewModel(task: task, project: project, account: account)))
                    }
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
                    taskDetailDestination: { task, project in
                        AnyView(TaskDetailView(viewModel: container.makeTaskDetailViewModel(task: task, project: project, account: account)))
                    }
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
                    }
                )
            }

            Tab(value: AppTab.search, role: .search) {
                SearchRootView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(VikunjaColor.brandPrimary)
        .overlay(alignment: .bottomTrailing) {
            QuickAddButton {
                isShowingQuickAdd = true
            }
            .padding(.trailing, VikunjaSpacing.md)
            .padding(.bottom, VikunjaSpacing.xxl + VikunjaSpacing.lg)
        }
        .sheet(isPresented: $isShowingQuickAdd) {
            QuickAddSheetView(viewModel: container.makeQuickAddTaskViewModel(account: account))
        }
    }
}
