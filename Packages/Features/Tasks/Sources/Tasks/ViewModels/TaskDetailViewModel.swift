import Foundation
import Observation
import VikunjaCore

/// Drives a single task's detail screen. `task` starts as whatever was passed
/// in at navigation time (so the screen shows content immediately, no
/// blank/spinner flash) and `load()` refreshes it from the server.
@MainActor
@Observable
public final class TaskDetailViewModel {
    public let project: Project
    public private(set) var task: VikunjaTask
    public private(set) var loadState: ScreenLoadState = .idle

    public var isLoading: Bool { loadState == .loading }

    private let repository: TaskRepositoryProtocol

    public init(task: VikunjaTask, project: Project, repository: TaskRepositoryProtocol) {
        self.task = task
        self.project = project
        self.repository = repository
    }

    public func load() async {
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            task = try await repository.fetchTask(id: task.id)
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    /// Flips the task's completion state, persists the change, and rolls the
    /// local flip back if the server rejects it — mirrors
    /// `ProjectOverviewViewModel.toggleDone(_:)`.
    public func toggleDone() async {
        let previous = task
        task.isDone.toggle()
        await persist(previous: previous)
    }

    /// Sets (or clears, via `nil`) the due date and persists it, rolling back
    /// on failure the same way `toggleDone()` does.
    public func setDueDate(_ dueDate: Date?) async {
        let previous = task
        task.dueDate = dueDate
        await persist(previous: previous)
    }

    /// Sets the priority and persists it, rolling back on failure the same
    /// way `toggleDone()` does.
    public func setPriority(_ priority: VikunjaTask.Priority) async {
        let previous = task
        task.priority = priority
        await persist(previous: previous)
    }

    /// Persists the currently-staged `task` edit, rolling back to `previous`
    /// if the server rejects it.
    ///
    /// Vikunja manages relations through their own endpoint rather than the
    /// task update body (see `TaskDTO.relatedTasks`), so `update(_:)`'s
    /// response doesn't carry `subtasks`/`dependsOn`/`blocks`/`otherRelations`
    /// back — carrying over what's already loaded instead of taking the
    /// response as-is is what keeps those sections from disappearing after an
    /// edit.
    private func persist(previous: VikunjaTask) async {
        do {
            var updated = try await repository.update(task)
            updated.subtasks = previous.subtasks
            updated.dependsOn = previous.dependsOn
            updated.blocks = previous.blocks
            updated.otherRelations = previous.otherRelations
            task = updated
        } catch {
            task = previous
        }
    }
}
