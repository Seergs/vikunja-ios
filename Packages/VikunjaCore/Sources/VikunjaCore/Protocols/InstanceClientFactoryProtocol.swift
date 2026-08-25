import Foundation

/// Builds a capability-detection client for an arbitrary instance URL. Used by
/// the onboarding flow to test a connection (`GET /api/v1/info`) before an
/// `InstanceAccount` exists for the composition root to wire a client through.
public protocol InstanceClientFactoryProtocol: Sendable {
    func makeCapabilityProvider(baseURL: URL) -> CapabilityProvider
}
