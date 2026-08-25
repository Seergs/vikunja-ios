import Foundation
import VikunjaCore

/// Builds a `CapabilityProvider` for an instance URL the user just typed in —
/// used by the onboarding flow to validate a connection (`GET /api/v1/info`)
/// before an `InstanceAccount` exists for the composition root to wire a
/// long-lived client through.
public struct VikunjaInstanceClientFactory: InstanceClientFactoryProtocol {
    public init() {}

    public func makeCapabilityProvider(baseURL: URL) -> CapabilityProvider {
        VikunjaCapabilityProvider(client: URLSessionAPIClient(baseURL: baseURL))
    }

    public func makeProjectRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> ProjectRepositoryProtocol {
        VikunjaProjectRepository(
            client: URLSessionAPIClient(baseURL: baseURL, authTokenProvider: tokenProvider)
        )
    }

    public func makeTaskRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskRepositoryProtocol {
        VikunjaTaskRepository(
            client: URLSessionAPIClient(baseURL: baseURL, authTokenProvider: tokenProvider)
        )
    }
}
