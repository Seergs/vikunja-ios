import Home
import Projects
import Search
import Settings
import SwiftUI
import VikunjaCore

/// The app's main navigation shell once a connection exists: a floating,
/// Liquid Glass tab bar (the default look for `TabView` on iOS 26+) with one
/// independent `NavigationStack` per tab, each owned by its own feature
/// module. `Search` uses iOS 26's dedicated `.search` tab role, which renders
/// it as a separated glass pill instead of grouping it with the others.
struct MainTabView: View {
    let account: InstanceAccount
    let container: AppContainer
    /// Called after the active connection is removed, so `RootView` can drop
    /// back to onboarding.
    let onDisconnect: () -> Void

    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                HomeRootView(accountName: account.displayName)
            }

            Tab(AppTab.projects.title, systemImage: AppTab.projects.systemImage, value: .projects) {
                ProjectsRootView(
                    viewModel: container.makeProjectsListViewModel(account: account),
                    makeOverviewViewModel: { node in
                        container.makeProjectOverviewViewModel(node: node, account: account)
                    }
                )
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                SettingsRootView(onResetConnection: resetConnection)
            }

            Tab(value: AppTab.search, role: .search) {
                SearchRootView()
            }
        }
        .tabViewBottomAccessory {
            // TODO: wire to real task creation once a Tasks feature exists.
            QuickAddAccessoryView()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    /// Temporary stand-in for real "edit connection" support: wipes the
    /// saved account/token and drops back to onboarding so the user can
    /// re-enter a fresh token. TODO: replace with in-place editing once
    /// Settings has a proper account screen.
    private func resetConnection() {
        Task {
            try? await container.accountStore.removeAccount(id: account.id)
            onDisconnect()
        }
    }
}
