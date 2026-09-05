import Foundation
import Testing
@testable import VikunjaCore

@Suite("InstanceAccount Codable")
struct InstanceAccountCodableTests {
    @Test
    func `decoding JSON saved before authMethod existed defaults to apiToken`() throws {
        let legacyJSON = """
        {
            "id": "8F9E6F2E-4B9B-4B8A-9C3A-6A3B0F1D2E3C",
            "displayName": "Home",
            "baseURL": "https://tasks.example.com",
            "createdAt": 0
        }
        """
        let decoder = JSONDecoder()
        let account = try decoder.decode(InstanceAccount.self, from: Data(legacyJSON.utf8))
        #expect(account.authMethod == .apiToken)
    }

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
