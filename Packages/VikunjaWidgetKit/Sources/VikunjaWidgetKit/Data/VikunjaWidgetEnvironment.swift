import Foundation
import VikunjaAuth
import VikunjaCore
import VikunjaNetworking

/// Builds the concrete `VikunjaAuth`/`VikunjaNetworking` types the widget
/// runs against — the widget's equivalent of the app target's `AppContainer`.
/// The extension is not a `Features/*` module, so importing the networking and
/// auth layers here is allowed.
public enum VikunjaWidgetEnvironment {
    public static func makeAccountStore() -> KeychainAccountStore {
        KeychainAccountStore(
            service: VikunjaWidgetConfig.accountStoreService,
            accessGroup: VikunjaWidgetConfig.keychainAccessGroup
        )
    }

    public static func makeSnapshotCache() -> TodaySnapshotCache {
        TodaySnapshotCache(appGroupIdentifier: VikunjaWidgetConfig.appGroupIdentifier)
    }

    public static func makeSnapshotLoader() -> TodaySnapshotLoader {
        TodaySnapshotLoader(
            accountStore: makeAccountStore(),
            clientFactory: VikunjaInstanceClientFactory(),
            cache: makeSnapshotCache()
        )
    }

    /// The active account plus its token, for the toggle-done `AppIntent`.
    public static func makeTaskRepository() async -> TaskRepositoryProtocol? {
        let store = makeAccountStore()
        guard let account = try? await store.activeAccount(),
              let token = try? await store.token(forAccountID: account.id),
              !token.isEmpty
        else { return nil }

        return VikunjaInstanceClientFactory().makeTaskRepository(baseURL: account.baseURL) { token }
    }
}
