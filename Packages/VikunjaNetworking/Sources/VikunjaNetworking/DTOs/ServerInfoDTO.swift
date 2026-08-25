/// Mirror of `GET /api/v1/info`. Vikunja exposes the feature flags enabled on this
/// instance here — it's the basis for `CapabilityProvider`.
struct ServerInfoDTO: Codable {
    let version: String
    let caldavEnabled: Bool?
    let totpEnabled: Bool?
    let registrationEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case version
        case caldavEnabled = "caldav_enabled"
        case totpEnabled = "totp_enabled"
        case registrationEnabled = "registration_enabled"
    }
}
