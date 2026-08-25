import Foundation
import Onboarding
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
}
