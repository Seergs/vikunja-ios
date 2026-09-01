import Foundation

/// A file attached to a task. Vikunja wraps the stored file's metadata
/// (`name`/`mime`/`size`) in a `TaskAttachment` that also records who uploaded
/// it and when; the bytes themselves are fetched separately through the
/// download endpoint. Kept out of `VikunjaTask` (like `TaskComment`) since
/// attachments are loaded and mutated through their own endpoint.
public struct TaskAttachment: Identifiable, Equatable, Sendable {
    public let id: Int
    public let taskID: Int
    public var fileName: String
    public var mimeType: String
    public var sizeBytes: Int
    public var created: Date
    public var createdBy: User

    public init(
        id: Int,
        taskID: Int,
        fileName: String,
        mimeType: String,
        sizeBytes: Int,
        created: Date,
        createdBy: User,
    ) {
        self.id = id
        self.taskID = taskID
        self.fileName = fileName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.created = created
        self.createdBy = createdBy
    }
}

/// Requested rendition when downloading an image attachment — Vikunja returns
/// a scaled-down preview instead of the original for `sm`/`md`/`lg`/`xl`
/// (`?preview_size=`), and the full file when unset.
public enum AttachmentPreviewSize: String, Sendable {
    case sm, md, lg, xl
}
