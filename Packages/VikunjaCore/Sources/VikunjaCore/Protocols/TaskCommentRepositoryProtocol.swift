public protocol TaskCommentRepositoryProtocol: Sendable {
    func fetchComments(taskID: Int) async throws -> [TaskComment]
    func addComment(_ text: String, toTask taskID: Int) async throws -> TaskComment
    func updateComment(_ commentID: Int, text: String, onTask taskID: Int) async throws -> TaskComment
    func deleteComment(_ commentID: Int, fromTask taskID: Int) async throws
}
