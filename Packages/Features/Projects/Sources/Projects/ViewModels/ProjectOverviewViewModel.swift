import Foundation
import Observation
import VikunjaCore

/// Drives a single project's overview screen: loads that project's tasks
/// from the server. `project` is fixed at construction — a different project
/// gets a new view model rather than this one being repointed.
@MainActor
@Observable
public final class ProjectOverviewViewModel {
    public let project: Project
    /// This project's direct children, handed down from the already-built
    /// tree (`ProjectsListViewModel.tree(from:)`) at navigation time rather
    /// than fetched again here.
    public let subprojects: [ProjectNode]
    public private(set) var tasks: [VikunjaTask] = []
    public private(set) var loadState: ScreenLoadState = .idle
    /// Each subproject's own task completion count, keyed by project id, for
    /// the "Subprojects" cards. Fetched alongside this project's own tasks
    /// since `ProjectNode` only carries project metadata, not tasks.
    public private(set) var subprojectTaskSummaries: [Int: TaskSummary] = [:]
    /// Every project on the instance, for the "Move to Project" picker —
    /// loaded lazily via `loadMoveCandidates()` rather than alongside
    /// `load()`, since most visits to this screen never open that picker.
    public private(set) var allProjects: [Project] = []

    public var isLoading: Bool { loadState == .loading }

    private let repository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting

    public init(
        project: Project,
        subprojects: [ProjectNode] = [],
        repository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting
    ) {
        self.project = project
        self.subprojects = subprojects
        self.repository = repository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
    }

    /// Kept as a nested name for call sites that already spell it
    /// `ProjectOverviewViewModel.TaskSummary`; the type itself is shared with
    /// the projects list (see `ProjectTaskSummary`).
    public typealias TaskSummary = ProjectTaskSummary

    /// Skips the `.loading` transition when there's already loaded content
    /// (i.e. this is a pull-to-refresh): swapping the list out for a
    /// spinner mid-refresh would tear down the `List` that owns the
    /// in-flight `.refreshable` task, cancelling its request underneath it.
    public func load() async {
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            tasks = try await repository.fetchTasks(projectID: project.id)
            subprojectTaskSummaries = await Self.fetchSubprojectSummaries(subprojects, repository: repository)
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    /// Fetches each subproject's own tasks concurrently so the "Subprojects"
    /// cards can show a real completion count instead of just a child-project
    /// count. A subproject whose fetch fails is left out rather than failing
    /// the whole screen — its card just falls back to "No tasks yet".
    private static func fetchSubprojectSummaries(
        _ nodes: [ProjectNode],
        repository: TaskRepositoryProtocol
    ) async -> [Int: TaskSummary] {
        await withTaskGroup(of: (Int, TaskSummary)?.self) { group in
            for node in nodes {
                group.addTask {
                    guard let tasks = try? await repository.fetchTasks(projectID: node.id) else { return nil }
                    return (node.id, TaskSummary(done: tasks.filter(\.isDone).count, total: tasks.count))
                }
            }
            var summaries: [Int: TaskSummary] = [:]
            for await result in group {
                if let (id, summary) = result {
                    summaries[id] = summary
                }
            }
            return summaries
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
            tasks[index] = try await repository.update(updated)
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
            try await repository.delete(id: task.id)
            tasks.removeAll { $0.id == task.id }
            toastPresenter.show("Task deleted", style: .success)
        } catch let error as VikunjaError {
            toastPresenter.show(error.displayMessage, style: .error)
        } catch {
            toastPresenter.show(error.localizedDescription, style: .error)
        }
    }

    /// Loads every project on the instance, for the "Move to Project"
    /// picker. Failures leave `allProjects` at whatever it already was — the
    /// picker just shows fewer candidates, mirroring
    /// `TaskDetailViewModel.loadAllProjects()`.
    public func loadMoveCandidates() async {
        allProjects = (try? await projectRepository.fetchProjects()) ?? allProjects
    }

    /// `allProjects` arranged for the "Move to Project" picker: one group per
    /// top-level project, each carrying its direct children (mirrors
    /// `QuickAddTaskViewModel.projectGroups` — only one level deep, not a
    /// full recursive tree), with this screen's own project excluded since
    /// moving a task there would be a no-op.
    public var moveProjectGroups: [ProjectGroup] {
        let candidates = allProjects.filter { $0.id != project.id }
        let childrenByParentID = Dictionary(grouping: candidates, by: \.parentProjectID)
        return (childrenByParentID[nil] ?? [])
            .sorted { $0.position < $1.position }
            .map { root in
                ProjectGroup(root: root, children: (childrenByParentID[root.id] ?? []).sorted { $0.position < $1.position })
            }
    }

    public struct ProjectGroup: Identifiable, Hashable {
        public let root: Project
        public let children: [Project]
        public var id: Int { root.id }
    }

    /// Moves `task` to `destination` and drops it from the local list on
    /// success — it no longer belongs to this project's screen, mirroring
    /// `delete(_:)`.
    public func move(_ task: VikunjaTask, to destination: Project) async {
        var updated = task
        updated.projectID = destination.id
        do {
            _ = try await repository.update(updated)
            tasks.removeAll { $0.id == task.id }
            toastPresenter.show("Task moved to \(destination.title)", style: .success)
        } catch let error as VikunjaError {
            toastPresenter.show(error.displayMessage, style: .error)
        } catch {
            toastPresenter.show(error.localizedDescription, style: .error)
        }
    }
}
