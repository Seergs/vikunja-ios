import Onboarding
import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// Top-level navigation between Features. Features never reference each other
/// directly, so switching from Onboarding to the main tab bar happens only
/// here, in the composition root. Also where the app's single toast host is
/// attached, so a toast floats above every screen — onboarding, tabs, and
/// sheets alike — regardless of which one triggered it.
struct RootView: View {
    let container: AppContainer

    @State private var connectedAccount: InstanceAccount?
    @State private var hasCheckedForSavedAccount = false

    var body: some View {
        Group {
            if let connectedAccount {
                // Keyed by the whole `InstanceAccount` value (not just its
                // id) so switching the active connection, or editing the
                // active one's own name/URL, tears down and rebuilds the
                // entire tab shell — every tab's view models were built
                // against the old account's `baseURL` at construction time
                // and don't observe changes to it.
                MainTabView(account: connectedAccount, container: container, onAccountsChanged: { Task { await refreshActiveAccount() } })
                    .id(connectedAccount)
            } else if hasCheckedForSavedAccount {
                NavigationStack {
                    InstanceSetupView(
                        viewModel: container.makeInstanceSetupViewModel(),
                        onConnectionSaved: { account in
                            connectedAccount = account
                        }
                    )
                }
            } else {
                ProgressView()
            }
        }
        .task {
            // The Keychain lookup is async, so without this the app would
            // always render onboarding first — even with a saved account —
            // until this resolves.
            await refreshActiveAccount()
            hasCheckedForSavedAccount = true
        }
        .toastHost(container.toastCenter)
    }

    /// Re-reads the active account from the store and updates
    /// `connectedAccount` accordingly — `nil` drops back to onboarding (e.g.
    /// the last connection was just deleted). `Settings`' view models fire
    /// their "active account changed" callback synchronously, so
    /// `MainTabView.onAccountsChanged` wraps this in its own `Task`.
    private func refreshActiveAccount() async {
        connectedAccount = try? await container.accountStore.activeAccount()
    }
}
