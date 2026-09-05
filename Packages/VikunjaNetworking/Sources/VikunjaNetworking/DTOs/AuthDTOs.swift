struct LoginRequestDTO: Encodable {
    let username: String
    let password: String
    let totpPasscode: String?
    let longToken: Bool

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case totpPasscode = "totp_passcode"
        case longToken = "long_token"
    }
}

struct AuthTokenDTO: Decodable {
    let token: String
}

/// What's actually persisted in the Keychain (via `AccountStoreProtocol`'s
/// opaque token slot) for a password-based account — the current access
/// token plus, on a v2.0+ server, the refresh token needed to renew it.
/// `nil` `refreshToken` signals a pre-2.0 server, where the access token
/// itself is renewed via `VikunjaEndpoints.userTokenRenew()` instead.
struct PasswordSessionCredential: Codable {
    let accessToken: String
    let refreshToken: String?
}
