import Foundation

/// Tolerant mirror of one entry of `/api/v1/tasks/{id}/comments`. Field
/// names must be confirmed against a real instance's swagger docs
/// (`/api/v1/docs`) before pointing this at an actual Vikunja server.
struct CommentDTO: Codable {
    let id: Int
    let comment: String
    let author: UserDTO
    let created: Date
    let updated: Date
}

/// Request body shared by `VikunjaEndpoints.createComment`/`updateComment`
/// — Vikunja's comment create/update endpoints both take just the text.
struct CommentRequestDTO: Codable {
    let comment: String
}
