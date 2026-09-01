import Foundation
import Testing
import VikunjaCore
@testable import VikunjaNetworking

struct TaskAttachmentDTOTests {
    @Test
    func `decodes realistic attachments payload`() throws {
        let dtos = try decode([TaskAttachmentDTO].self, from: "task-attachments")

        #expect(dtos.count == 2)
        #expect(dtos[0].file.name == "design-spec.pdf")
        #expect(dtos[0].file.mime == "application/pdf")
        #expect(dtos[0].file.size == 284_736)
        #expect(dtos[0].taskId == 42)
        #expect(dtos[1].createdBy.name == nil)
    }

    @Test
    func `maps to domain via attachment mapper`() throws {
        let dtos = try decode([TaskAttachmentDTO].self, from: "task-attachments")
        let attachments = dtos.map(AttachmentMapper.toDomain)

        #expect(attachments[0] == TaskAttachment(
            id: 1,
            taskID: 42,
            fileName: "design-spec.pdf",
            mimeType: "application/pdf",
            sizeBytes: 284_736,
            created: attachments[0].created,
            createdBy: User(id: 7, username: "alex", name: "Alex"),
        ))
        #expect(attachments[1].mimeType == "image/png")
    }

    @Test
    func `decodes the upload success envelope`() throws {
        let result = try decode(AttachmentUploadResultDTO.self, from: "task-attachment-upload")

        #expect(result.errors?.isEmpty == true)
        let success = try #require(result.success)
        #expect(success.count == 1)
        #expect(success[0].id == 3)
        #expect(AttachmentMapper.toDomain(success[0]).fileName == "notes.txt")
    }

    private func decode<T: Decodable>(_ type: T.Type, from fixture: String) throws -> T {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
