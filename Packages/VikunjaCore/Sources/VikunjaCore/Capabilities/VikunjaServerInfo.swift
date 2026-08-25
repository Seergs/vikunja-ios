public struct VikunjaServerInfo: Equatable, Sendable {
    public let version: String
    public let caldavEnabled: Bool
    public let totpEnabled: Bool
    public let registrationEnabled: Bool
    public let maxFileSizeBytes: Int?

    public init(
        version: String,
        caldavEnabled: Bool,
        totpEnabled: Bool,
        registrationEnabled: Bool,
        maxFileSizeBytes: Int? = nil
    ) {
        self.version = version
        self.caldavEnabled = caldavEnabled
        self.totpEnabled = totpEnabled
        self.registrationEnabled = registrationEnabled
        self.maxFileSizeBytes = maxFileSizeBytes
    }
}
