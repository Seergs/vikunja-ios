public protocol TaskRelationRepositoryProtocol: Sendable {
    func addRelation(kind: RelationKind, otherTaskID: Int, toTask taskID: Int) async throws
    func removeRelation(kind: RelationKind, otherTaskID: Int, fromTask taskID: Int) async throws
}
