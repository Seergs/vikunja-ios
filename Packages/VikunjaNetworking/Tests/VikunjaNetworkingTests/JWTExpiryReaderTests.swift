import Foundation
import Testing
@testable import VikunjaNetworking

struct JWTExpiryReaderTests {
    @Test
    func `reads the exp claim from A well formed JWT`() {
        let jwt = makeJWT(exp: 1_700_000_000)

        #expect(JWTExpiryReader.expiry(of: jwt) == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test
    func `returns nil for malformed input`() {
        #expect(JWTExpiryReader.expiry(of: "not-a-jwt") == nil)
        #expect(JWTExpiryReader.expiry(of: "") == nil)
        #expect(JWTExpiryReader.expiry(of: "a.b") == nil)
    }

    private func makeJWT(exp: Double) -> String {
        let header = base64URL(Data(#"{"alg":"HS256"}"#.utf8))
        let payload = base64URL(Data(#"{"exp":\#(exp)}"#.utf8))
        return "\(header).\(payload).signature"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
