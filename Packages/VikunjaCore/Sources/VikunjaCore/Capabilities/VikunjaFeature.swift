public enum VikunjaFeature: Sendable {
    case caldav
    case totp
    case registration
    /// Whether the instance has username/password login enabled.
    case localAuth
    /// Whether the instance has at least one OIDC provider configured.
    case openIDConnect
}
