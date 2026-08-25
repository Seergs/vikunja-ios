import SwiftUI
import VikunjaNavigation

/// Projects' entry point for the app target: owns the tab's own
/// `NavigationStack` and `Router<ProjectsRoute>`, so pushing a screen from
/// inside Projects never needs the app target or another feature to know
/// about it.
public struct ProjectsRootView: View {
    @State private var router = Router<ProjectsRoute>()

    public init() {}

    public var body: some View {
        // `.navigationDestination(for: ProjectsRoute.self)` lands here once
        // `ProjectsRoute` has its first real case.
        NavigationStack(path: $router.path) {
            ProjectsView()
        }
    }
}
