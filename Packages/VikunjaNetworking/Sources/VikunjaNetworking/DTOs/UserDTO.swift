struct UserDTO: Codable {
    let id: Int
    let username: String
    let name: String?
    let email: String?
    /// Only present on the `GET /api/v1/user` response — absent when a
    /// `UserDTO` shows up embedded elsewhere (e.g. a comment's author).
    let settings: UserSettingsDTO?

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, settings
    }
}

struct UserSettingsDTO: Codable {
    let defaultProjectId: Int?

    enum CodingKeys: String, CodingKey {
        case defaultProjectId = "default_project_id"
    }
}
