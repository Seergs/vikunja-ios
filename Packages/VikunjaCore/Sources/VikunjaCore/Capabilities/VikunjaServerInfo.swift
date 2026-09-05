public struct VikunjaServerInfo: Equatable, Sendable {
    public let version: String
    public let caldavEnabled: Bool
    public let totpEnabled: Bool
    public let registrationEnabled: Bool
    public let maxFileSizeBytes: Int?
    /// Whether the instance has username/password login enabled. Older
    /// servers don't report this at all, in which case this defaults to
    /// `true` — we can't distinguish "explicitly disabled" from "server too
    /// old to say," so we assume it's available rather than hide it.
    public let localAuthEnabled: Bool
    /// OIDC providers configured on this instance. Empty when OIDC is
    /// disabled, none are configured, or the server predates this field.
    public let oidcProviders: [OIDCProvider]

    public init(
        version: String,
        caldavEnabled: Bool,
        totpEnabled: Bool,
        registrationEnabled: Bool,
        maxFileSizeBytes: Int? = nil,
        localAuthEnabled: Bool = true,
        oidcProviders: [OIDCProvider] = [],
    ) {
        self.version = version
        self.caldavEnabled = caldavEnabled
        self.totpEnabled = totpEnabled
        self.registrationEnabled = registrationEnabled
        self.maxFileSizeBytes = maxFileSizeBytes
        self.localAuthEnabled = localAuthEnabled
        self.oidcProviders = oidcProviders
    }
}
