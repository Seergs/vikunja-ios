import VikunjaCore

enum AttachmentMapper {
    static func toDomain(_ dto: TaskAttachmentDTO) -> TaskAttachment {
        TaskAttachment(
            id: dto.id,
            taskID: dto.taskId,
            fileName: dto.file.name,
            mimeType: dto.file.mime,
            sizeBytes: dto.file.size,
            created: dto.created,
            createdBy: UserMapper.toDomain(dto.createdBy),
        )
    }
}
