import SwiftUI
import VikunjaNavigation

/// Projects' entry point for the app target: owns the tab's own
/// `NavigationStack` and `Router<ProjectsRoute>`, so pushing a screen from
/// inside Projects never needs the app target or another feature to know
/// about it.
public struct ProjectsRootView: View {
    @State private var router = Router<ProjectsRoute>()
    private let viewModel: ProjectsListViewModel
    private let makeOverviewViewModel: (ProjectNode) -> ProjectOverviewViewModel

    /// `makeOverviewViewModel` comes from the app target's `AppContainer`,
    /// which is the only place allowed to know about the concrete task
    /// repository a `ProjectOverviewViewModel` needs.
    public init(
        viewModel: ProjectsListViewModel,
        makeOverviewViewModel: @escaping (ProjectNode) -> ProjectOverviewViewModel
    ) {
        self.viewModel = viewModel
        self.makeOverviewViewModel = makeOverviewViewModel
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            ProjectsView(viewModel: viewModel, router: router)
                .navigationDestination(for: ProjectsRoute.self) { route in
                    switch route {
                    case let .projectOverview(node):
                        ProjectOverviewView(viewModel: makeOverviewViewModel(node), router: router)
                    }
                }
        }
    }
}
