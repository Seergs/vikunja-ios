import SwiftUI
import VikuNavigation
import VikunjaCore

/// Calendar's entry point for the app target: owns the tab's own
/// `NavigationStack` and `Router<CalendarRoute>`, so pushing a screen from
/// inside Calendar never needs the app target or another feature to know
/// about it.
public struct CalendarRootView: View {
    @State private var router = Router<CalendarRoute>()
    private let viewModel: CalendarViewModel
    private let taskDetailDestination: (VikunjaTask, Project) -> AnyView

    /// `taskDetailDestination` comes from the app target's `AppContainer`, the
    /// only place allowed to know about the concrete `Tasks` view this pushes
    /// — type-erased so this package never imports `Tasks` directly, mirroring
    /// `HomeRootView`.
    public init(
        viewModel: CalendarViewModel,
        taskDetailDestination: @escaping (VikunjaTask, Project) -> AnyView,
    ) {
        self.viewModel = viewModel
        self.taskDetailDestination = taskDetailDestination
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            CalendarView(viewModel: viewModel, router: router)
                .navigationDestination(for: CalendarRoute.self) { route in
                    switch route {
                    case let .taskDetail(task, project):
                        taskDetailDestination(task, project)
                    }
                }
        }
    }
}
