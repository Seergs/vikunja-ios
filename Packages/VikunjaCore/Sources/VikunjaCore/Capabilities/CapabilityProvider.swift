public protocol CapabilityProvider: Sendable {
    func serverInfo() async throws -> VikunjaServerInfo
    func supports(_ feature: VikunjaFeature) async -> Bool
}
