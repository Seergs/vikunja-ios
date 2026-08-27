/// View-specific load state shared by this feature's screens — not a domain
/// model. Each screen's view model owns its own content alongside this
/// (`tasks`, ...); this only tracks the request lifecycle.
public enum ScreenLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failure(String)
}
