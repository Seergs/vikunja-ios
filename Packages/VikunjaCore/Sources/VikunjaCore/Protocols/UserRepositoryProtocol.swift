/// Reads the signed-in user (`GET /api/v1/user`). Kept separate from
/// `AuthServiceProtocol` (which only knows how to exchange credentials for a
/// token) and from `ProjectRepositoryProtocol` — the current consumer is
/// quick-add's project preselection, which needs the user's
/// `defaultProjectID`, and reading that is a user query, not a project one.
public protocol UserRepositoryProtocol: Sendable {
    func fetchCurrentUser() async throws -> User
}
