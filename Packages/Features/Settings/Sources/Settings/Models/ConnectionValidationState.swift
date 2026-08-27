/// View-specific state for the "add/edit connection" form — not a domain
/// model. Mirrors `Onboarding`'s `InstanceSetupValidationState` (duplicated
/// rather than shared, same as `VikunjaError.displayMessage` — neither
/// package depends on the other).
public enum ConnectionValidationState: Equatable, Sendable {
    case idle
    case validating
    case success
    case failure(String)
}
