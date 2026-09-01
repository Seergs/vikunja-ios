import Foundation
import Testing
@testable import VikunjaNetworking

struct ServerInfoDTOTests {
    @Test
    func `maps capability flags to domain`() throws {
        let url = try #require(Bundle.module.url(forResource: "server_info", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(ServerInfoDTO.self, from: data)

        let info = ServerInfoMapper.toDomain(dto)

        #expect(info.version == "0.24.6")
        #expect(info.caldavEnabled == true)
        #expect(info.totpEnabled == true)
        #expect(info.registrationEnabled == false)
        #expect(info.maxFileSizeBytes == 20 * 1024 * 1024)
    }

    @Test(arguments: [
        ("20MB", 20 * 1024 * 1024),
        ("20 MB", 20 * 1024 * 1024),
        ("20mb", 20 * 1024 * 1024),
        ("1GB", 1024 * 1024 * 1024),
        ("500KB", 500 * 1024),
        ("20MiB", 20 * 1024 * 1024),
        ("1048576", 1_048_576),
    ])
    func `parses max file size strings`(input: String, expected: Int) {
        #expect(MaxFileSizeParser.bytes(from: input) == expected)
    }

    @Test(arguments: ["", "  ", "lots", "MB", "-5MB", "12PB"])
    func `returns nil for unparseable max file size`(input: String) {
        #expect(MaxFileSizeParser.bytes(from: input) == nil)
    }

    @Test
    func `returns nil when max file size is absent`() {
        #expect(MaxFileSizeParser.bytes(from: nil) == nil)
    }
}
