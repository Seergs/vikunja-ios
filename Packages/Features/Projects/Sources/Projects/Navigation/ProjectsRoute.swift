/// Destinations pushable within the Projects tab's own navigation stack.
public enum ProjectsRoute: Hashable, Sendable {
    /// A single project's overview screen. Carries the whole `ProjectNode`
    /// (not just the `Project`) so its "Subprojects" section — and further
    /// drill-down into one of those — never needs a second project fetch.
    case projectOverview(ProjectNode)
}
