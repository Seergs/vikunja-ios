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
    func mapsOtherRelationKindsGenerically() throws {
        let dto = try loadTaskDTO()
        let task = TaskMapper.toDomain(dto)

        #expect(task.otherRelations[.related] == [TaskRelation(id: 6, title: "Buy filters", isDone: false, projectID: 4)])
        #expect(task.otherRelations[.precedes] == [TaskRelation(id: 7, title: "Clean machine", isDone: false, projectID: 4)])
        #expect(task.otherRelations[.follows] == [TaskRelation(id: 8, title: "Descale machine", isDone: true, projectID: 4)])
        #expect(task.otherRelations[.subtask] == nil)
        #expect(task.otherRelations[.blocked] == nil)
        #expect(task.otherRelations[.blocking] == nil)
    }

    @Test
    func toleratesAMissingRelatedTasksField() throws {
        let dto = try loadTaskDTO(named: "task-no-due-date")
        let task = TaskMapper.toDomain(dto)

        #expect(task.subtasks.isEmpty)
        #expect(task.dependsOn.isEmpty)
        #expect(task.blocks.isEmpty)
        #expect(task.otherRelations.isEmpty)
    }

    @Test
    func mergePreservesFieldsVikunjaTaskDoesntTrack() throws {
        let current = try loadTaskDTO()
        var task = TaskMapper.toDomain(current)
        task.isDone.toggle()

        let merged = TaskMapper.merge(task, onto: current)

        #expect(merged.done == true)
        #expect(merged.percentDone == 0.5)
        #expect(merged.hexColor == "00ff00")
        #expect(merged.isFavorite == true)
        #expect(merged.doneAt == current.doneAt)
        #expect(merged.startDate == current.startDate)
        #expect(merged.endDate == current.endDate)
        #expect(merged.repeatAfter == 604_800)
        #expect(merged.repeatMode == 1)
        #expect(merged.coverImageAttachmentId == 42)
        #expect(merged.reminders == current.reminders)
        #expect(merged.assignees == current.assignees)
        #expect(merged.relatedTasks?["subtask"]?.first?.title == "Grind beans")
    }

    @Test
    func mergedTaskRoundTripsOpaqueFieldsThroughEncoding() throws {
        let current = try loadTaskDTO()
        var task = TaskMapper.toDomain(current)
        task.isDone.toggle()
        let merged = TaskMapper.merge(task, onto: current)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(merged)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TaskDTO.self, from: data)

        // `assignees` carries a field ("extra_field_not_yet_modeled") this
        // DTO doesn't know about — proving it survives the round trip is the
        // whole point of `JSONValue` over a concretely-typed shape.
        #expect(decoded.assignees == current.assignees)
        #expect(decoded.reminders == current.reminders)
        #expect(decoded.percentDone == current.percentDone)
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
