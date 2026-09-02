import Foundation
import Testing
@testable import VikunjaNetworking

struct UserDTOTests {
    @Test
    func `decodes the current user payload with nested settings`() throws {
        let dto = try loadUserDTO()

        #expect(dto.id == 3)
        #expect(dto.username == "qa-user")
        #expect(dto.settings?.defaultProjectId == 6)
    }

    @Test
    func `maps the nested default project ID onto the domain user`() throws {
        let user = try UserMapper.toDomain(loadUserDTO())

        #expect(user.defaultProjectID == 6)
    }

    /// Vikunja returns `0` (never null) when the user hasn't picked a default
    /// project; the mapper must normalize that to `nil` so quick-add doesn't
    /// try to preselect a project with id 0.
    @Test
    func `normalizes an unset default project to nil`() {
        let dto = UserDTO(
            id: 1,
            username: "x",
            name: nil,
            email: nil,
            settings: UserSettingsDTO(defaultProjectId: 0),
        )

        #expect(UserMapper.toDomain(dto).defaultProjectID == nil)
    }

    @Test
    func `tolerates A user payload with no settings block`() throws {
        let data = Data(#"{"id": 9, "username": "author", "name": "Author"}"#.utf8)
        let dto = try JSONDecoder().decode(UserDTO.self, from: data)

        #expect(dto.settings == nil)
        #expect(UserMapper.toDomain(dto).defaultProjectID == nil)
    }

    private func loadUserDTO() throws -> UserDTO {
        let url = try #require(Bundle.module.url(forResource: "user", withExtension: "json"))
        return try JSONDecoder().decode(UserDTO.self, from: Data(contentsOf: url))
    }
}
