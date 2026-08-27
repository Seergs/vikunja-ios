import VikunjaCore

public final class VikunjaTaskCommentRepository: TaskCommentRepositoryProtocol {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func fetchComments(taskID: Int) async throws -> [TaskComment] {
        let dtos: [CommentDTO] = try await client.send(VikunjaEndpoints.comments(taskID: taskID))
        return dtos.map(CommentMapper.toDomain)
    }

    public func addComment(_ text: String, toTask taskID: Int) async throws -> TaskComment {
        let endpoint = try VikunjaEndpoints.createComment(taskID: taskID, text: text)
        let dto: CommentDTO = try await client.send(endpoint)
        return CommentMapper.toDomain(dto)
    }

    public func updateComment(_ commentID: Int, text: String, onTask taskID: Int) async throws -> TaskComment {
        let endpoint = try VikunjaEndpoints.updateComment(taskID: taskID, commentID: commentID, text: text)
        let dto: CommentDTO = try await client.send(endpoint)
        return CommentMapper.toDomain(dto)
    }

    public func deleteComment(_ commentID: Int, fromTask taskID: Int) async throws {
        try await client.send(VikunjaEndpoints.deleteComment(taskID: taskID, commentID: commentID))
    }
}
