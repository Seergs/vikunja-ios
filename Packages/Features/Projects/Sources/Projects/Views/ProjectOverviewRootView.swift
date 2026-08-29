import SwiftUI
import VikunjaCore

/// A second, narrower entry point into this package: a single project's
/// overview screen, pushed as a leaf from another feature's stack (Tasks,
/// today — see `TaskDetailView`'s project pill) rather than reached by
/// walking `ProjectsRootView`'s own list.
///
/// Unlike `ProjectsRootView`, this owns no `NavigationStack`/`Router` of its
/// own — it's meant to be pushed onto whatever ambient stack already hosts
/// it, the same way `TaskDetailView` pushes a nested copy of itself via
/// `navigationDestination(item:)` without owning a stack. A further push here
/// (a subproject, one of this project's tasks) recurses the same way: a
/// subproject pushes another `ProjectOverviewRootView`, a task hands off to
/// the caller's `taskDetailDestination`.
///
/// The seed `viewModel` here was built from a bare `Project` rather than a
/// `ProjectNode` from an already-loaded tree (the caller doesn't have one),
/// so its `subprojects` is empty and the "Subprojects" section simply
/// doesn't render — acceptable for a screen reached from outside Projects,
/// where seeing this project's own tasks is the point.
public struct ProjectOverviewRootView: View {
    private let viewModel: ProjectOverviewViewModel
    private let makeOverviewViewModel: (ProjectNode) -> ProjectOverviewViewModel
    private let taskDetailDestination: (VikunjaTask, Project) -> AnyView
    @State private var subprojectDestination: ProjectNode?
    @State private var taskDestinationBox: TaskDestinationBox?

    public init(
        viewModel: ProjectOverviewViewModel,
        makeOverviewViewModel: @escaping (ProjectNode) -> ProjectOverviewViewModel,
        taskDetailDestination: @escaping (VikunjaTask, Project) -> AnyView
    ) {
        self.viewModel = viewModel
        self.makeOverviewViewModel = makeOverviewViewModel
        self.taskDetailDestination = taskDetailDestination
    }

    public var body: some View {
        ProjectOverviewView(
            viewModel: viewModel,
            onSelectSubproject: { subprojectDestination = $0 },
            onSelectTask: { task in
                taskDestinationBox = TaskDestinationBox(
                    id: task.id,
                    content: taskDetailDestination(task, viewModel.project)
                )
            },
            onEditProject: { _ in }
        )
        // Concrete-typed content (another `ProjectOverviewRootView`), so this
        // one doesn't need the box treatment below — see
        // `TaskDestinationBox`'s doc comment.
        .navigationDestination(item: $subprojectDestination) { node in
            ProjectOverviewRootView(
                viewModel: makeOverviewViewModel(node),
                makeOverviewViewModel: makeOverviewViewModel,
                taskDetailDestination: taskDetailDestination
            )
        }
        .navigationDestination(item: $taskDestinationBox) { box in
            box.content
        }
    }
}

/// Wraps the type-erased `AnyView` `taskDetailDestination` builds, computed
/// once at selection time (in `onSelectTask` above) rather than inside the
/// `.navigationDestination(item:)` closure. That closure re-runs on every
/// re-render of this screen, and since `AnyView` erases the type identity
/// SwiftUI would otherwise use to recognize "same destination" across those
/// reruns, rebuilding it fresh each time tore the pushed task screen down and
/// remounted it repeatedly — see `Tasks`' `ProjectDestinationBox`, the same
/// fix for the same failure mode one level up (a project pushed from a
/// task's project pill).
private struct TaskDestinationBox: Identifiable, Hashable {
    let id: Int
    let content: AnyView

    // Written by hand: `AnyView` isn't `Hashable`, and identity here only
    // ever needs to key off `id` anyway.
    static func == (lhs: TaskDestinationBox, rhs: TaskDestinationBox) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
