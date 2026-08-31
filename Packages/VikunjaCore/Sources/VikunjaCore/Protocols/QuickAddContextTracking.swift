/// Tracks which project the currently visible screen is scoped to, so a
/// globally-presented quick-add sheet can default its project to that one
/// instead of always to the account default.
///
/// Screens that represent a single project (a project overview, a task's
/// detail) call `enterProjectScope(_:)` when they appear and
/// `exitProjectScope(_:)` when they go away. It's a stack rather than a single
/// slot: pushing a task detail on top of its project's overview means two
/// scopes for the same project id are active at once, and the enter/exit
/// events can arrive in either order — the stack stays correct regardless, and
/// `preselectedProjectID` is simply the innermost (most recently entered)
/// still-active scope. Every screen that isn't project-scoped leaves the stack
/// untouched, so `preselectedProjectID` reads `nil` there, which the quick-add
/// flow treats as "use the account's default project".
///
/// Implemented by the app target (`QuickAddContext`) and injected the same way
/// `ToastPresenting` is.
@MainActor
public protocol QuickAddContextTracking: AnyObject {
    func enterProjectScope(_ projectID: Int)
    func exitProjectScope(_ projectID: Int)
    var preselectedProjectID: Int? { get }
}
