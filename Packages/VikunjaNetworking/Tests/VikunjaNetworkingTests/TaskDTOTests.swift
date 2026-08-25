import Foundation
import Testing
import VikunjaCore
@testable import VikunjaNetworking

struct TaskDTOTests {
    @Test
    func decodesRealisticTaskPayload() throws {
        let dto = try loadTaskDTO()

        #expect(dto.id == 1)
        #expect(dto.title == "Buy coffee")
        #expect(dto.projectId == 4)
        #expect(dto.labels?.first?.hexColor == "ff00ff")
    }

    @Test
    func mapsToDomainModel() throws {
        let dto = try loadTaskDTO()
        let task = TaskMapper.toDomain(dto)

        #expect(task.id == 1)
        #expect(task.priority == .high)
        #expect(task.labels.count == 1)
        #expect(task.labels.first?.title == "home")
    }

    @Test
    func mapsRelatedTasksBySubtaskBlockedAndBlockingKind() throws {
        let dto = try loadTaskDTO()
        let task = TaskMapper.toDomain(dto)

        #expect(task.subtasks == [TaskRelation(id: 2, title: "Grind beans", isDone: true, projectID: 4)])
        #expect(task.dependsOn == [TaskRelation(id: 3, title: "Buy grinder", isDone: false, projectID: 4)])
        #expect(task.blocks == [TaskRelation(id: 5, title: "Make espresso", isDone: false, projectID: 4)])
        #expect(task.isBlocked == true)
    }

    @Test
    func toleratesAMissingRelatedTasksField() throws {
        let dto = try loadTaskDTO(named: "task-no-due-date")
        let task = TaskMapper.toDomain(dto)

        #expect(task.subtasks.isEmpty)
        #expect(task.dependsOn.isEmpty)
        #expect(task.blocks.isEmpty)
    }

    @Test
    func mapsZeroValueDueDateToNil() throws {
        let dto = try loadTaskDTO(named: "task-no-due-date")
        let task = TaskMapper.toDomain(dto)

        #expect(task.dueDate == nil)
    }

    private func loadTaskDTO(named name: String = "task") throws -> TaskDTO {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TaskDTO.self, from: data)
    }
}
