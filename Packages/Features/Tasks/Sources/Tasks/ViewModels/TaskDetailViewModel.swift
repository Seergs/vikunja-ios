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
    /// Candidates for the "add relation" task picker, from the most recent
    /// `searchTasksForRelation(query:)` call.
    public private(set) var relationSearchResults: [VikunjaTask] = []
    /// Every project on the instance, for resolving a relation candidate's
    /// project name in the "add relation" task picker — loaded lazily via
    /// `loadAllProjects()` rather than alongside `load()`, the same reasoning
    /// as `allLabels`/`loadAllLabels()`.
    public private(set) var allProjects: [Project] = []

    public var isLoading: Bool { loadState == .loading }

    private let repository: TaskRepositoryProtocol
    private let labelRepository: LabelRepositoryProtocol
    private let relationRepository: TaskRelationRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting

    public init(
        task: VikunjaTask,
        project: Project,
        repository: TaskRepositoryProtocol,
        labelRepository: LabelRepositoryProtocol,
        relationRepository: TaskRelationRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting
    ) {
        self.task = task
        self.project = project
        self.repository = repository
        self.labelRepository = labelRepository
        self.relationRepository = relationRepository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
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

    /// Adds `relation` under `kind` to the task, optimistically, rolling back
    /// if the server rejects it — mirrors `toggleLabel(_:)`. `relation`'s
    /// display fields (title/isDone/projectID) come from wherever the caller
    /// found the other task (e.g. a search/picker), since Vikunja's
    /// create-relation response only echoes ids, not those fields.
    public func addRelation(_ relation: TaskRelation, kind: RelationKind) async {
        let previous = task
        insertRelation(relation, kind: kind)
        do {
            try await relationRepository.addRelation(kind: kind, otherTaskID: relation.id, toTask: task.id)
            toastPresenter.show("Relation added", style: .success)
        } catch {
            task = previous
        }
    }

    /// Removes `relation` under `kind` from the task, optimistically, rolling
    /// back if the server rejects it — mirrors `toggleLabel(_:)`.
    public func removeRelation(_ relation: TaskRelation, kind: RelationKind) async {
        let previous = task
        deleteRelation(relation, kind: kind)
        do {
            try await relationRepository.removeRelation(kind: kind, otherTaskID: relation.id, fromTask: task.id)
        } catch {
            task = previous
        }
    }

    /// Searches every task the account can see for the "add relation" task
    /// picker, excluding the task itself and anything already related to it
    /// (under any relation kind) so the same task can't be picked twice. An
    /// empty or all-whitespace query falls back to `loadRelationSuggestions()`
    /// rather than clearing the results, so the picker never shows a blank
    /// list just because the user cleared their search. Failures leave
    /// `relationSearchResults` empty rather than surfacing an error — the
    /// sheet just shows no candidates.
    public func searchTasksForRelation(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await loadRelationSuggestions()
            return
        }
        let excludedIDs = relatedTaskIDs.union([task.id])
        let results = (try? await repository.searchTasks(query: query)) ?? []
        relationSearchResults = results.filter { !excludedIDs.contains($0.id) }
    }

    /// Populates `relationSearchResults` with this task's own project's other
    /// tasks before the user has typed anything — most relations (subtasks,
    /// dependencies, blockers) are within the same project, so this saves a
    /// search for the common case. Excludes the task itself and anything
    /// already related to it, the same as `searchTasksForRelation(query:)`.
    public func loadRelationSuggestions() async {
        let excludedIDs = relatedTaskIDs.union([task.id])
        let results = (try? await repository.fetchTasks(projectID: project.id)) ?? []
        relationSearchResults = results.filter { !excludedIDs.contains($0.id) }
    }

    /// Loads every project on the instance, for the "add relation" task
    /// picker to show which project each candidate belongs to. Failures
    /// leave `allProjects` at whatever it already was — the picker just
    /// shows fewer project names, the same tradeoff `loadAllLabels()` makes.
    public func loadAllProjects() async {
        allProjects = (try? await projectRepository.fetchProjects()) ?? allProjects
    }

    /// Resolves `relation` to the full task and its project, for navigating
    /// to that task's own detail screen when a relation row is tapped —
    /// `TaskRelation` only carries an id/title/isDone/projectID summary, not
    /// enough to push a `TaskDetailView`. Loads `allProjects` first if it
    /// hasn't been already, mirroring the "add relation" picker's lazy load.
    /// Returns `nil` if either fetch fails, or the project can't be resolved.
    public func loadRelatedTask(_ relation: TaskRelation) async -> (VikunjaTask, Project)? {
        guard let relatedTask = try? await repository.fetchTask(id: relation.id) else { return nil }
        if relation.projectID == project.id {
            return (relatedTask, project)
        }
        if allProjects.isEmpty {
            await loadAllProjects()
        }
        guard let relatedProject = allProjects.first(where: { $0.id == relation.projectID }) else { return nil }
        return (relatedTask, relatedProject)
    }

    /// Builds a `TaskDetailViewModel` for a related task, reusing this
    /// view model's own dependencies — lets `TaskDetailView` push another
    /// instance of itself for a tapped relation without the app target's
    /// `AppContainer` needing to know about the recursion.
    public func makeDetailViewModel(task: VikunjaTask, project: Project) -> TaskDetailViewModel {
        TaskDetailViewModel(
            task: task,
            project: project,
            repository: repository,
            labelRepository: labelRepository,
            relationRepository: relationRepository,
            projectRepository: projectRepository,
            toastPresenter: toastPresenter
        )
    }

    /// Resolves `id` to a project title — the current task's own project
    /// (always known, no network needed) or, once `loadAllProjects()` has
    /// run, any other project on the instance. Returns `nil` if `id` isn't
    /// the current project and hasn't been loaded into `allProjects` yet.
    public func projectTitle(forProjectID id: Int) -> String? {
        if id == project.id { return project.title }
        return allProjects.first { $0.id == id }?.title
    }

    /// Every task id already related to this one, across `subtasks`,
    /// `dependsOn`, `blocks`, and every kind in `otherRelations` — used to
    /// exclude already-related tasks from the relation search results.
    private var relatedTaskIDs: Set<Int> {
        var ids = Set((task.subtasks + task.dependsOn + task.blocks).map(\.id))
        for relations in task.otherRelations.values {
            ids.formUnion(relations.map(\.id))
        }
        return ids
    }

    /// Routes `relation` into whichever of `task`'s relation properties
    /// `kind` corresponds to — the named `subtasks`/`dependsOn`/`blocks`
    /// fields for those three kinds, `otherRelations` for everything else.
    private func insertRelation(_ relation: TaskRelation, kind: RelationKind) {
        switch kind {
        case .subtask: task.subtasks.append(relation)
        case .blocked: task.dependsOn.append(relation)
        case .blocking: task.blocks.append(relation)
        default: task.otherRelations[kind, default: []].append(relation)
        }
    }

    private func deleteRelation(_ relation: TaskRelation, kind: RelationKind) {
        switch kind {
        case .subtask: task.subtasks.removeAll { $0.id == relation.id }
        case .blocked: task.dependsOn.removeAll { $0.id == relation.id }
        case .blocking: task.blocks.removeAll { $0.id == relation.id }
        default:
            task.otherRelations[kind]?.removeAll { $0.id == relation.id }
            if task.otherRelations[kind]?.isEmpty == true {
                task.otherRelations[kind] = nil
            }
        }
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
