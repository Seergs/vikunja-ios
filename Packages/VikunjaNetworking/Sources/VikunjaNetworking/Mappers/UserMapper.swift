import VikunjaCore

enum UserMapper {
    static func toDomain(_ dto: UserDTO) -> User {
        User(id: dto.id, username: dto.username, name: dto.name, email: dto.email)
    }
}
