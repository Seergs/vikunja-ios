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
    let providers: [OIDCProviderDTO]?
}

/// One entry of `auth.openid_connect.providers`. Field names are best-effort
/// (mirrored from Vikunja's frontend config shape) and **must be verified
/// against a live instance's swagger docs (`/api/v1/docs`)** before pointing
/// this at a real server.
struct OIDCProviderDTO: Codable {
    let name: String?
    let key: String?
    let authURL: String?
    let clientID: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case name
        case key
        case authURL = "authUrl"
        case clientID = "clientId"
        case scope
    }
}
