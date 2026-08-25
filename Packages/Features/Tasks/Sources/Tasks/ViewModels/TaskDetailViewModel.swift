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
    /// Every label on the instance, for the label picker sheet to offer —
    /// loaded lazily via `loadAllLabels()` rather than alongside `load()`,
    /// since most task views are never opened.
    public private(set) var allLabels: [Label] = []

    public var isLoading: Bool { loadState == .loading }

    private let repository: TaskRepositoryProtocol
    private let labelRepository: LabelRepositoryProtocol

    public init(task: VikunjaTask, project: Project, repository: TaskRepositoryProtocol, labelRepository: LabelRepositoryProtocol) {
        self.task = task
        self.project = project
        self.repository = repository
        self.labelRepository = labelRepository
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

    /// Loads every label on the instance, for the label picker sheet. Failures
    /// leave `allLabels` at whatever it already was (empty on first failure),
    /// rather than surfacing an error — the sheet just shows fewer/no
    /// suggestions to pick from.
    public func loadAllLabels() async {
        allLabels = (try? await labelRepository.fetchLabels()) ?? allLabels
    }

    /// Adds or removes `label` from the task, optimistically, rolling back if
    /// the server rejects it — mirrors `toggleDone()`.
    public func toggleLabel(_ label: Label) async {
        let previous = task
        if task.labels.contains(label) {
            task.labels.removeAll { $0.id == label.id }
            do {
                try await labelRepository.removeLabel(label.id, fromTask: task.id)
            } catch {
                task = previous
            }
        } else {
            task.labels.append(label)
            do {
                try await labelRepository.addLabel(label.id, toTask: task.id)
            } catch {
                task = previous
            }
        }
    }

    /// Creates a new label on the instance and attaches it to the task.
    /// Rolls back to no-op if either the create or the attach request fails —
    /// there's no partial state to reconcile since `allLabels` is reloaded
    /// from the create response rather than guessed at.
    public func createAndAddLabel(title: String, hexColor: String) async {
        guard let created = try? await labelRepository.create(Label(id: 0, title: title, hexColor: hexColor)) else {
            return
        }
        allLabels.append(created)
        await toggleLabel(created)
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
