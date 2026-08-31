/// Reads the signed-in user (`GET /api/v1/user`). Kept separate from
/// `AuthServiceProtocol` (which only knows how to exchange credentials for a
/// token) and from `ProjectRepositoryProtocol` — the current consumer is the
/// app's once-per-launch refresh of the cached `defaultProjectID` for
/// quick-add, and reading that is a user query, not a project one.
public protocol UserRepositoryProtocol: Sendable {
    func fetchCurrentUser() async throws -> User
}
