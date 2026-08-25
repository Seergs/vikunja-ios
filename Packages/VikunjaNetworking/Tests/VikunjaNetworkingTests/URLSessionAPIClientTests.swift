import Foundation
import Testing
import VikunjaCore
@testable import VikunjaNetworking

// MockURLProtocol uses static state shared across requests, so this suite runs
// serialized to avoid clobbering itself with tests running in parallel.
@Suite(.serialized)
struct URLSessionAPIClientTests {
    @Test
    func decodesSuccessfulResponse() async throws {
        let (session, _) = MockURLProtocol.makeSession(statusCode: 200, body: #"{"version":"0.24.6"}"#)
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)

        let info: ServerInfoDTO = try await client.send(VikunjaEndpoints.info())

        #expect(info.version == "0.24.6")
    }

    @Test
    func mapsUnauthorizedStatusToDomainError() async throws {
        let (session, _) = MockURLProtocol.makeSession(statusCode: 401, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)

        await #expect(throws: VikunjaError.unauthorized) {
            let _: ServerInfoDTO = try await client.send(VikunjaEndpoints.info())
        }
    }

    @Test
    func attachesBearerTokenFromProvider() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: #"{"version":"0.24.6"}"#)
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://vikunja.example.com")!,
            session: session,
            authTokenProvider: { "test-token" }
        )

        let _: ServerInfoDTO = try await client.send(VikunjaEndpoints.info())

        #expect(await capture.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }
}
