import VikunjaCore

public final class VikunjaUserRepository: UserRepositoryProtocol {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func fetchCurrentUser() async throws -> User {
        let dto: UserDTO = try await client.send(VikunjaEndpoints.currentUser())
        return UserMapper.toDomain(dto)
    }
}
