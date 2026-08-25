import VikunjaCore

/// Destinations pushable within the Projects tab's own navigation stack.
public enum ProjectsRoute: Hashable, Sendable {
    /// A single project's overview screen. Carries the whole `ProjectNode`
    /// (not just the `Project`) so its "Subprojects" section — and further
    /// drill-down into one of those — never needs a second project fetch.
    case projectOverview(ProjectNode)
    /// A single task's detail screen. Carries the owning `Project` alongside
    /// the task (not just its id) so the detail screen's project pill/swatch
    /// never needs a second fetch — mirrors `projectOverview` carrying its
    /// `ProjectNode`.
    case taskDetail(VikunjaTask, Project)
}
