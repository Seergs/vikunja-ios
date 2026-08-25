public protocol AuthServiceProtocol: Sendable {
    func login(username: String, password: String) async throws -> AuthSession
    func loginWithAPIToken(_ token: String) async throws -> AuthSession
    func logout() async
}

public struct AuthSession: Sendable {
    public let token: String
    public let user: User

    public init(token: String, user: User) {
        self.token = token
        self.user = user
    }
}
