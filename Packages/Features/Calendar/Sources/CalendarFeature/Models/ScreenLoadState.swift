/// View-specific load state for this feature's screen — not a domain model.
/// The view model owns its own content alongside this (`tasks`,
/// `projectsByID`); this only tracks the request lifecycle.
public enum ScreenLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failure(String)
}
