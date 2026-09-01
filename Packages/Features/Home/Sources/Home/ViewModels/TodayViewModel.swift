import Foundation
import Observation
import VikunjaCore

/// Drives the Today screen: the account's tasks across every project,
/// grouped/filtered by due date in `TodayView`. Unlike `Projects`' screens,
/// there's no single project scoping the fetch — every project's tasks are
/// pulled and merged here.
@MainActor
@Observable
public final class TodayViewModel {
    public private(set) var tasks: [VikunjaTask] = []
    /// Looked up per row for the project color dot + name, since a task only
    /// carries its `projectID`.
    public private(set) var projectsByID: [Int: Project] = [:]
    public private(set) var loadState: ScreenLoadState = .idle
    /// Every project on the instance, for the "Move to Project" picker —
    /// loaded lazily via `loadMoveCandidates()` rather than alongside
    /// `load()`, since most visits to this screen never open that picker.
    public private(set) var allProjects: [Project] = []

    public var isLoading: Bool {
        loadState == .loading
    }

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting,
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
    }

    /// Skips the `.loading` transition when there's already loaded content
    /// (i.e. this is a pull-to-refresh): swapping the list out for a
    /// spinner mid-refresh would tear down the `List` that owns the
    /// in-flight `.refreshable` task, cancelling its request underneath it.
    public func load() async {
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            let projects = try await projectRepository.fetchProjects()
            projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
            tasks = await Self.fetchAllTasks(projects: projects, repository: taskRepository)
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    /// Fetches every project's tasks concurrently and flattens them into one
    /// list. A project whose fetch fails is dropped rather than failing the
    /// whole screen — mirrors `ProjectOverviewViewModel.fetchSubprojectSummaries`.
    private static func fetchAllTasks(
        projects: [Project],
        repository: TaskRepositoryProtocol,
    ) async -> [VikunjaTask] {
        await withTaskGroup(of: [VikunjaTask].self) { group in
            for project in projects {
                group.addTask {
                    await (try? repository.fetchTasks(projectID: project.id)) ?? []
                }
            }
            var allTasks: [VikunjaTask] = []
            for await tasks in group {
                allTasks.append(contentsOf: tasks)
            }
            return allTasks
        }
    }

    /// Flips a task's completion state, persists the change, and rolls the
    /// local flip back if the server rejects it — so a failed request never
    /// leaves the row showing a state the server doesn't actually have.
    public func toggleDone(_ task: VikunjaTask) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.isDone.toggle()
        tasks[index] = updated
        do {
            tasks[index] = try await taskRepository.update(updated)
        } catch {
            tasks[index] = task
        }
    }

    /// Deletes a task from the server and drops it from the local list on
    /// success. Vikunja soft-deletes tasks server-side rather than cascading
    /// the delete to subtasks/relations, so nothing else in the tree needs
    /// updating here.
    public func delete(_ task: VikunjaTask) async {
        do {
            try await taskRepository.delete(id: task.id)
            tasks.removeAll { $0.id == task.id }
            toastPresenter.show("Task deleted", style: .success)
        } catch let error as VikunjaError {
            toastPresenter.show(error.displayMessage, style: .error)
        } catch {
            toastPresenter.show(error.localizedDescription, style: .error)
        }
    }

    /// Loads every project on the instance, for the "Move to Project"
    /// picker. Failures leave `allProjects` at whatever it already was.
    public func loadMoveCandidates() async {
        allProjects = await (try? projectRepository.fetchProjects()) ?? allProjects
    }

    /// Moves `task` to `destination` and drops it from the local list on
    /// success — it no longer belongs to the Today view after the move.
    public func move(_ task: VikunjaTask, to destination: Project) async {
        var updated = task
        updated.projectID = destination.id
        do {
            _ = try await taskRepository.update(updated)
            tasks.removeAll { $0.id == task.id }
            toastPresenter.show("Task moved to \(destination.title)", style: .success)
        } catch let error as VikunjaError {
            toastPresenter.show(error.displayMessage, style: .error)
        } catch {
            toastPresenter.show(error.localizedDescription, style: .error)
        }
    }
}
