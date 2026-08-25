import SwiftUI
import VikunjaNavigation

/// Search's entry point for the app target: owns the tab's own
/// `NavigationStack` and `Router<SearchRoute>`, so pushing a screen from
/// inside Search never needs the app target or another feature to know about
/// it.
public struct SearchRootView: View {
    @State private var router = Router<SearchRoute>()

    public init() {}

    public var body: some View {
        // `.navigationDestination(for: SearchRoute.self)` lands here once
        // `SearchRoute` has its first real case.
        NavigationStack(path: $router.path) {
            SearchView()
        }
    }
}
