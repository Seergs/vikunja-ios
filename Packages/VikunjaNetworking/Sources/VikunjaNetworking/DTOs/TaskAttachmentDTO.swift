import Foundation

/// Tolerant mirror of one entry of `GET /api/v1/tasks/{id}/attachments` (and
/// of each element of an upload response's `success` array). Field names
/// verified against `pkg/models/task_attachment.go` / `pkg/files/files.go`;
/// re-check against a live instance's `/api/v1/docs` before pointing this at a
/// real server.
struct TaskAttachmentDTO: Codable {
    let id: Int
    let taskId: Int
    let createdBy: UserDTO
    let file: FileDTO
    let created: Date

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case createdBy = "created_by"
        case file
        case created
    }
}

/// The stored-file metadata Vikunja nests under `TaskAttachment.file`. The
/// bytes themselves come from the download endpoint, not this object.
struct FileDTO: Codable {
    let id: Int
    let name: String
    let mime: String
    let size: Int
    let created: Date
}

/// `PUT /api/v1/tasks/{id}/attachments` response — a partial-success envelope:
/// each file either lands in `success` or contributes an entry to `errors`,
/// and a per-file failure doesn't fail the request.
struct AttachmentUploadResultDTO: Codable {
    let success: [TaskAttachmentDTO]?
    let errors: [AttachmentUploadErrorDTO]?
}

struct AttachmentUploadErrorDTO: Codable {
    let code: Int?
    let message: String?
}
