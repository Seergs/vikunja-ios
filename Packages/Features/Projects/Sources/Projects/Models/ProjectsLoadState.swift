/// View-specific state for the projects list screen — not a domain model,
/// stays local to this feature.
public enum ProjectsLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failure(String)
}
