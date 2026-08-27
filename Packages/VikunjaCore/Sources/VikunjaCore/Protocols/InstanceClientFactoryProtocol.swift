import Foundation

/// Builds clients for a given instance URL. Used both by the onboarding flow,
/// to test a connection (`GET /api/v1/info`) before an `InstanceAccount`
/// exists, and by the composition root, to wire an authenticated repository
/// through for an already-connected account.
public protocol InstanceClientFactoryProtocol: Sendable {
    func makeCapabilityProvider(baseURL: URL) -> CapabilityProvider

    /// - Parameter tokenProvider: resolves the account's bearer token per
    ///   request, so the repository never caches a token that's since been
    ///   rotated or removed.
    func makeProjectRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> ProjectRepositoryProtocol

    func makeTaskRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskRepositoryProtocol

    func makeLabelRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> LabelRepositoryProtocol

    func makeTaskRelationRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskRelationRepositoryProtocol

    func makeTaskCommentRepository(
        baseURL: URL,
        tokenProvider: @escaping @Sendable () async -> String?
    ) -> TaskCommentRepositoryProtocol
}
