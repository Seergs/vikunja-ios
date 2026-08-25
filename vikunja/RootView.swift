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
                MainTabView(
                    account: connectedAccount,
                    container: container,
                    onDisconnect: { self.connectedAccount = nil }
                )
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
            connectedAccount = try? await container.accountStore.activeAccount()
            hasCheckedForSavedAccount = true
        }
        .toastHost(container.toastCenter)
    }
}
