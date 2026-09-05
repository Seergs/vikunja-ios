import Foundation

/// The inputs to a username/password login attempt (`AuthServiceProtocol.login`).
public struct LoginCredentials: Sendable {
    public var username: String
    public var password: String
    /// The account's TOTP code, if it has two-factor auth enabled. `nil` on
    /// the first attempt; a caller that gets back `VikunjaError.totpRequired`
    /// should retry with this filled in.
    public var totpPasscode: String?
    /// Requests a longer-lived session ("remember me").
    public var longToken: Bool

    public init(username: String, password: String, totpPasscode: String? = nil, longToken: Bool = false) {
        self.username = username
        self.password = password
        self.totpPasscode = totpPasscode
        self.longToken = longToken
    }
}
