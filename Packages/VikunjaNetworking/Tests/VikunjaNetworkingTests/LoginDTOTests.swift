import Foundation
import Testing
@testable import VikunjaNetworking

struct LoginDTOTests {
    @Test
    func `encodes totp passcode and long token in snake case`() throws {
        let dto = LoginRequestDTO(username: "sergio", password: "hunter2", totpPasscode: "123456", longToken: true)

        let json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: Any],
        )

        #expect(json["username"] as? String == "sergio")
        #expect(json["password"] as? String == "hunter2")
        #expect(json["totp_passcode"] as? String == "123456")
        #expect(json["long_token"] as? Bool == true)
    }

    @Test
    func `omits the totp passcode key when nil`() throws {
        let dto = LoginRequestDTO(username: "sergio", password: "hunter2", totpPasscode: nil, longToken: false)

        let json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: Any],
        )

        #expect(json["totp_passcode"] == nil)
        #expect(json["long_token"] as? Bool == false)
    }
}
