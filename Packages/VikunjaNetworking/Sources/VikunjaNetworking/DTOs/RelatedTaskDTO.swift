/// Tolerant mirror of one entry inside a `TaskDTO`'s `related_tasks` map.
/// Vikunja represents a related task as a full task object, but only these
/// fields are needed to build a `TaskRelation` — see `TaskRelationMapper`.
struct RelatedTaskDTO: Codable {
    let id: Int
    let title: String
    let done: Bool
    let projectId: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, done
        case projectId = "project_id"
    }
}
