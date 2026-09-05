/// Mirror of `GET /api/v1/info`. Vikunja exposes the feature flags enabled on this
/// instance here — it's the basis for `CapabilityProvider`.
struct ServerInfoDTO: Codable {
    let version: String
    let caldavEnabled: Bool?
    let totpEnabled: Bool?
    let registrationEnabled: Bool?
    /// The instance's upload cap as a human-readable string (e.g. `"20MB"`) —
    /// `MaxFileSizeParser` turns it into a byte count. Absent on older
    /// servers.
    let maxFileSize: String?
    /// Which login methods are enabled. Absent entirely on servers old
    /// enough to predate this field — see `AuthInfoDTO`.
    let auth: AuthInfoDTO?

    enum CodingKeys: String, CodingKey {
        case version
        case caldavEnabled = "caldav_enabled"
        case totpEnabled = "totp_enabled"
        case registrationEnabled = "registration_enabled"
        case maxFileSize = "max_file_size"
        case auth
    }
}

/// Not modeled: `openid_connect.providers` (OIDC is out of scope for now).
struct AuthInfoDTO: Codable {
    let local: LocalAuthInfoDTO?
    let openidConnect: OpenIDAuthInfoDTO?

    enum CodingKeys: String, CodingKey {
        case local
        case openidConnect = "openid_connect"
    }
}

struct LocalAuthInfoDTO: Codable {
    let enabled: Bool?
}

struct OpenIDAuthInfoDTO: Codable {
    let enabled: Bool?
}
