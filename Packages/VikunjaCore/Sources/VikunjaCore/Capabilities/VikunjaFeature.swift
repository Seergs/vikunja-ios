public enum VikunjaFeature: Sendable {
    case caldav
    case totp
    case registration
    /// Whether the instance has username/password login enabled.
    /// `.openIDConnect` will join this once OIDC support lands.
    case localAuth
}
