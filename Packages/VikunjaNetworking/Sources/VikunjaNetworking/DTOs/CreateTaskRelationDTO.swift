/// Request body for `VikunjaEndpoints.createTaskRelation`.
struct CreateTaskRelationDTO: Codable {
    let relationKind: String
    let otherTaskId: Int

    enum CodingKeys: String, CodingKey {
        case relationKind = "relation_kind"
        case otherTaskId = "other_task_id"
    }
}
