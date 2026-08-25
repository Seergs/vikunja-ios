import SwiftUI
import VikunjaNavigation

/// Settings' entry point for the app target: owns the tab's own
/// `NavigationStack` and `Router<SettingsRoute>`, so pushing a screen from
/// inside Settings never needs the app target or another feature to know
/// about it.
public struct SettingsRootView: View {
    @State private var router = Router<SettingsRoute>()
    private let onResetConnection: () -> Void

    public init(onResetConnection: @escaping () -> Void) {
        self.onResetConnection = onResetConnection
    }

    public var body: some View {
        // `.navigationDestination(for: SettingsRoute.self)` lands here once
        // `SettingsRoute` has its first real case.
        NavigationStack(path: $router.path) {
            SettingsView(onResetConnection: onResetConnection)
        }
    }
}
