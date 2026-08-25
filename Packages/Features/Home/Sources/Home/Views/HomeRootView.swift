import SwiftUI
import VikunjaNavigation

/// Home's entry point for the app target: owns the tab's own `NavigationStack`
/// and `Router<HomeRoute>`, so pushing a screen from inside Home never needs
/// the app target or another feature to know about it.
public struct HomeRootView: View {
    private let accountName: String

    @State private var router = Router<HomeRoute>()

    public init(accountName: String) {
        self.accountName = accountName
    }

    public var body: some View {
        // `.navigationDestination(for: HomeRoute.self)` lands here once `HomeRoute`
        // has its first real case — an exhaustive switch over an empty enum has no
        // `View` to return, so there's nothing to wire up yet.
        NavigationStack(path: $router.path) {
            HomeView(accountName: accountName)
        }
    }
}
