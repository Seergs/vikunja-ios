import Foundation
import VikunjaCore
@testable import Tasks

final class FakeTaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    var tasks: [VikunjaTask] = []
    var fetchError: VikunjaError?
    var updateError: VikunjaError?
    var deleteError: VikunjaError?
    var searchError: VikunjaError?
    var searchResults: [VikunjaTask] = []

    func fetchTasks(projectID: Int) async throws -> [VikunjaTask] {
        if let fetchError { throw fetchError }
        return tasks.filter { $0.projectID == projectID }
    }

    func fetchTask(id: Int) async throws -> VikunjaTask {
        if let fetchError { throw fetchError }
        guard let task = tasks.first(where: { $0.id == id }) else {
            throw VikunjaError.notFound
        }
        return task
    }

    func create(_ task: VikunjaTask) async throws -> VikunjaTask { task }

    func update(_ task: VikunjaTask) async throws -> VikunjaTask {
        if let updateError { throw updateError }
        // Mirrors the real API: an update's response doesn't echo relations
        // back (see `TaskDetailViewModel.toggleDone()`'s doc comment).
        var updated = task
        updated.subtasks = []
        updated.dependsOn = []
        updated.blocks = []
        updated.otherRelations = [:]
        return updated
    }

    func delete(id: Int) async throws {
        if let deleteError { throw deleteError }
        tasks.removeAll { $0.id == id }
    }

    func searchTasks(query: String) async throws -> [VikunjaTask] {
        if let searchError { throw searchError }
        return searchResults
    }
}

final class FakeProjectRepository: ProjectRepositoryProtocol, @unchecked Sendable {
    var projects: [Project] = []
    var fetchError: VikunjaError?

    func fetchProjects() async throws -> [Project] {
        if let fetchError { throw fetchError }
        return projects
    }

    func fetchProject(id: Int) async throws -> Project {
        guard let project = projects.first(where: { $0.id == id }) else {
            throw VikunjaError.notFound
        }
        return project
    }

    func create(_ project: Project) async throws -> Project { project }

    func update(_ project: Project) async throws -> Project { project }

    func delete(id: Int) async throws {
        projects.removeAll { $0.id == id }
    }
}

final class FakeLabelRepository: LabelRepositoryProtocol, @unchecked Sendable {
    var labels: [Label] = []
    var addedLabelIDs: [(labelID: Int, taskID: Int)] = []
    var removedLabelIDs: [(labelID: Int, taskID: Int)] = []
    var fetchError: VikunjaError?
    var createError: VikunjaError?
    var addError: VikunjaError?
    var removeError: VikunjaError?
    private var nextID = 100

    func fetchLabels() async throws -> [Label] {
        if let fetchError { throw fetchError }
        return labels
    }

    func create(_ label: Label) async throws -> Label {
        if let createError { throw createError }
        let created = Label(id: nextID, title: label.title, hexColor: label.hexColor)
        nextID += 1
        labels.append(created)
        return created
    }

    func update(_ label: Label) async throws -> Label { label }

    func delete(id: Int) async throws {
        labels.removeAll { $0.id == id }
    }

    func addLabel(_ labelID: Int, toTask taskID: Int) async throws {
        if let addError { throw addError }
        addedLabelIDs.append((labelID, taskID))
    }

    func removeLabel(_ labelID: Int, fromTask taskID: Int) async throws {
        if let removeError { throw removeError }
        removedLabelIDs.append((labelID, taskID))
    }
}

final class FakeTaskRelationRepository: TaskRelationRepositoryProtocol, @unchecked Sendable {
    var addedRelations: [(kind: RelationKind, otherTaskID: Int, taskID: Int)] = []
    var removedRelations: [(kind: RelationKind, otherTaskID: Int, taskID: Int)] = []
    var addError: VikunjaError?
    var removeError: VikunjaError?

    func addRelation(kind: RelationKind, otherTaskID: Int, toTask taskID: Int) async throws {
        if let addError { throw addError }
        addedRelations.append((kind, otherTaskID, taskID))
    }

    func removeRelation(kind: RelationKind, otherTaskID: Int, fromTask taskID: Int) async throws {
        if let removeError { throw removeError }
        removedRelations.append((kind, otherTaskID, taskID))
    }
}

final class FakeTaskCommentRepository: TaskCommentRepositoryProtocol, @unchecked Sendable {
    var comments: [TaskComment] = []
    var fetchError: VikunjaError?
    var addError: VikunjaError?
    var updateError: VikunjaError?
    var deleteError: VikunjaError?
    private var nextID = 100

    func fetchComments(taskID: Int) async throws -> [TaskComment] {
        if let fetchError { throw fetchError }
        return comments
    }

    func addComment(_ text: String, toTask taskID: Int) async throws -> TaskComment {
        if let addError { throw addError }
        let created = TaskComment(
            id: nextID,
            comment: text,
            author: User(id: 1, username: "me"),
            created: Date(),
            updated: Date()
        )
        nextID += 1
        comments.append(created)
        return created
    }

    func updateComment(_ commentID: Int, text: String, onTask taskID: Int) async throws -> TaskComment {
        if let updateError { throw updateError }
        guard let index = comments.firstIndex(where: { $0.id == commentID }) else {
            throw VikunjaError.notFound
        }
        comments[index].comment = text
        comments[index].updated = Date()
        return comments[index]
    }

    func deleteComment(_ commentID: Int, fromTask taskID: Int) async throws {
        if let deleteError { throw deleteError }
        comments.removeAll { $0.id == commentID }
    }
}

final class FakeTaskAssistant: TaskAssistantProtocol, @unchecked Sendable {
    var availability: TaskAssistantAvailability = .available
    var result = "Looks actionable. Consider adding a due date."
    var error: (any Error)?
    private(set) var reviewedTitles: [String] = []

    func reviewTask(title: String, description: String) async throws -> String {
        reviewedTitles.append(title)
        if let error { throw error }
        return result
    }
}

final class FakeToastPresenter: ToastPresenting, @unchecked Sendable {
    private(set) var shownMessages: [(message: String, style: ToastStyle)] = []

    func show(_ message: String, style: ToastStyle) {
        shownMessages.append((message, style))
    }
}
