import SwiftUI
import VikunjaCore
import VikunjaNavigation

/// Projects' entry point for the app target: owns the tab's own
/// `NavigationStack` and `Router<ProjectsRoute>`, so pushing a screen from
/// inside Projects never needs the app target or another feature to know
/// about it.
public struct ProjectsRootView: View {
    @State private var router = Router<ProjectsRoute>()
    private let viewModel: ProjectsListViewModel
    private let makeOverviewViewModel: (ProjectNode) -> ProjectOverviewViewModel
    private let taskDetailDestination: (VikunjaTask, Project) -> AnyView

    /// `makeOverviewViewModel` and `taskDetailDestination` come from the app
    /// target's `AppContainer`, the only place allowed to know about the
    /// concrete task repository these view models need.
    /// `taskDetailDestination` is type-erased (rather than returning a
    /// concrete `Tasks.TaskDetailView`) so this package never imports the
    /// `Tasks` package — the same decoupling this whole app already relies
    /// on, just extended from "build a view model" to "build a view" since
    /// this particular destination lives in a different feature module.
    public init(
        viewModel: ProjectsListViewModel,
        makeOverviewViewModel: @escaping (ProjectNode) -> ProjectOverviewViewModel,
        taskDetailDestination: @escaping (VikunjaTask, Project) -> AnyView
    ) {
        self.viewModel = viewModel
        self.makeOverviewViewModel = makeOverviewViewModel
        self.taskDetailDestination = taskDetailDestination
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            ProjectsView(viewModel: viewModel, router: router)
                .navigationDestination(for: ProjectsRoute.self) { route in
                    switch route {
                    case let .projectOverview(node):
                        ProjectOverviewView(viewModel: makeOverviewViewModel(node), router: router)
                    case let .taskDetail(task, project):
                        taskDetailDestination(task, project)
                    }
                }
        }
    }
}
