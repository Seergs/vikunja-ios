import VikunjaCore

enum UserMapper {
    static func toDomain(_ dto: UserDTO) -> User {
        User(
            id: dto.id,
            username: dto.username,
            name: dto.name,
            email: dto.email,
            // `default_project_id` is nested under `settings` on the
            // `GET /api/v1/user` response, and Vikunja reports an unset value
            // as `0` rather than null.
            defaultProjectID: dto.settings?.defaultProjectId.flatMap { $0 == 0 ? nil : $0 }
        )
    }
}
