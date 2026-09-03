import VikunjaCore

/// Destinations pushable within the Calendar tab's own navigation stack.
public enum CalendarRoute: Hashable, Sendable {
    /// A single task's detail screen. Carries the owning `Project` alongside
    /// the task (not just its id) so the detail screen's project pill/swatch
    /// never needs a second fetch — mirrors `HomeRoute.taskDetail`.
    case taskDetail(VikunjaTask, Project)
}
