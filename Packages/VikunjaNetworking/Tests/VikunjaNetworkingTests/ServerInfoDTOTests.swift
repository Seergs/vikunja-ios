import Foundation
import Testing
@testable import VikunjaNetworking

struct ServerInfoDTOTests {
    @Test
    func mapsCapabilityFlagsToDomain() throws {
        let url = try #require(Bundle.module.url(forResource: "server_info", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(ServerInfoDTO.self, from: data)

        let info = ServerInfoMapper.toDomain(dto)

        #expect(info.version == "0.24.6")
        #expect(info.caldavEnabled == true)
        #expect(info.totpEnabled == true)
        #expect(info.registrationEnabled == false)
    }
}
