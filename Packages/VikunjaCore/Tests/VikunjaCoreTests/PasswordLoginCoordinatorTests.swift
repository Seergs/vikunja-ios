import Testing
@testable import VikunjaCore

@Suite("PasswordLoginCoordinator")
struct PasswordLoginCoordinatorTests {
    @Test
    func `a successful login returns the session`() async {
        let session = AuthSession(token: "opaque-blob", user: User(id: 1, username: "sergio"))
        let coordinator = PasswordLoginCoordinator(authService: FakeAuthService(result: .success(session)))

        let state = await coordinator.attempt(username: "sergio", password: "hunter2")

        #expect(state == .success(session))
    }

    @Test
    func `a totpRequired error surfaces as awaitingTOTP, not a failure`() async {
        let coordinator = PasswordLoginCoordinator(authService: FakeAuthService(result: .failure(.totpRequired)))

        let state = await coordinator.attempt(username: "sergio", password: "hunter2")

        #expect(state == .awaitingTOTP)
    }

    @Test
    func `retrying with a TOTP code after awaitingTOTP can succeed`() async {
        let session = AuthSession(token: "opaque-blob", user: User(id: 1, username: "sergio"))
        let service = FakeAuthService(result: .failure(.totpRequired))
        let coordinator = PasswordLoginCoordinator(authService: service)
        _ = await coordinator.attempt(username: "sergio", password: "hunter2")

        service.result = .success(session)
        let state = await coordinator.retryWithTOTP("123456", username: "sergio", password: "hunter2")

        #expect(state == .success(session))
    }

    @Test
    func `a wrong-password error surfaces as a plain failure`() async {
        let coordinator = PasswordLoginCoordinator(authService: FakeAuthService(result: .failure(.unauthorized)))

        let state = await coordinator.attempt(username: "sergio", password: "wrong")

        #expect(state == .failure(.unauthorized))
    }
}

private final class FakeAuthService: AuthServiceProtocol, @unchecked Sendable {
    var result: Result<AuthSession, VikunjaError>

    init(result: Result<AuthSession, VikunjaError>) {
        self.result = result
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        try result.get()
    }

    func loginWithAPIToken(_ token: String) async throws -> AuthSession {
        try result.get()
    }

    func logout() async {}
}
