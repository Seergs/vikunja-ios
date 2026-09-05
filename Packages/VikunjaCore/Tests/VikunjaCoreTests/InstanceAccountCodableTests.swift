import Foundation
import Testing
@testable import VikunjaCore

@Suite("InstanceAccount Codable")
struct InstanceAccountCodableTests {
    @Test
    func `round-trips a password account through encode/decode`() throws {
        let account = try InstanceAccount(
            displayName: "Home",
            baseURL: #require(URL(string: "https://tasks.example.com")),
            authMethod: .password,
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(InstanceAccount.self, from: encoder.encode(account))
        #expect(decoded == account)
        #expect(decoded.authMethod == .password)
    }
}
