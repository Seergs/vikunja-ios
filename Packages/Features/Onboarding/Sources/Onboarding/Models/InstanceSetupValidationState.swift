/// View-specific state for the "add a connection" screen — not a domain model,
/// stays local to this feature.
public enum InstanceSetupValidationState: Equatable, Sendable {
    case idle
    case validating
    case success
    case failure(String)
}
