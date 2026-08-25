import VikunjaCore

public final class VikunjaTaskRelationRepository: TaskRelationRepositoryProtocol {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func addRelation(kind: RelationKind, otherTaskID: Int, toTask taskID: Int) async throws {
        try await client.send(VikunjaEndpoints.createTaskRelation(taskID: taskID, kind: kind, otherTaskID: otherTaskID))
    }

    public func removeRelation(kind: RelationKind, otherTaskID: Int, fromTask taskID: Int) async throws {
        try await client.send(VikunjaEndpoints.deleteTaskRelation(taskID: taskID, kind: kind, otherTaskID: otherTaskID))
    }
}
