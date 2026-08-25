import Onboarding
import SwiftUI
import VikunjaCore

/// Top-level navigation between Features. Features never reference each other
/// directly, so switching from Onboarding to the main tab bar happens only
/// here, in the composition root.
struct RootView: View {
    let container: AppContainer

    @State private var connectedAccount: InstanceAccount?

    var body: some View {
        if let connectedAccount {
            MainTabView(account: connectedAccount)
        } else {
            NavigationStack {
                InstanceSetupView(
                    viewModel: container.makeInstanceSetupViewModel(),
                    onConnectionSaved: { account in
                        connectedAccount = account
                    }
                )
            }
        }
    }
}
