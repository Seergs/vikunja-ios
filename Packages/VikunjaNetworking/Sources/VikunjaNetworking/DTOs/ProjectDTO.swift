struct ProjectDTO: Codable {
    let id: Int
    let title: String
    let description: String?
    let isArchived: Bool?
    let isFavorite: Bool?
    let parentProjectId: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case isArchived = "is_archived"
        case isFavorite = "is_favorite"
        case parentProjectId = "parent_project_id"
    }
}
