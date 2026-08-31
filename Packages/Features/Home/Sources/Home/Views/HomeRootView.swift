import SwiftUI
import VikunjaCore
import VikunjaNavigation

/// Home's entry point for the app target: owns the tab's own `NavigationStack`
/// and `Router<HomeRoute>`, so pushing a screen from inside Home never needs
/// the app target or another feature to know about it.
public struct HomeRootView: View {
    @State private var router = Router<HomeRoute>()
    private let viewModel: TodayViewModel
    private let taskDetailDestination: (VikunjaTask, Project) -> AnyView

    /// `taskDetailDestination` comes from the app target's `AppContainer`,
    /// the only place allowed to know about the concrete `Tasks` view this
    /// pushes — type-erased so this package never imports `Tasks` directly,
    /// mirroring `ProjectsRootView`'s `taskDetailDestination`.
    public init(
        viewModel: TodayViewModel,
        taskDetailDestination: @escaping (VikunjaTask, Project) -> AnyView,
    ) {
        self.viewModel = viewModel
        self.taskDetailDestination = taskDetailDestination
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            TodayView(viewModel: viewModel, router: router)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case let .taskDetail(task, project):
                        taskDetailDestination(task, project)
                    }
                }
        }
    }
}
