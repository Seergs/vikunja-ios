import Observation
import VikunjaCore

/// Drives the quick-add sheet: title + project + priority only, matching the
/// design mockup's `AddTaskSheet` (no due date/labels/assignee yet). Opened
/// from the tab bar's floating action button rather than from within a
/// project, so there's no project to default to — `selectedProjectID` starts
/// `nil` and `canSave` stays false until the user picks one explicitly.
@MainActor
@Observable
public final class QuickAddTaskViewModel {
    public var title: String = ""
    public var selectedProjectID: Int?
    public var priority: VikunjaTask.Priority = .unset
    public private(set) var projects: [Project] = []
    public private(set) var loadState: ScreenLoadState = .idle
    public private(set) var isSaving: Bool = false
    public private(set) var saveErrorMessage: String?

    public var isLoading: Bool { loadState == .loading }

    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedProjectID != nil && !isSaving
    }

    public var selectedProject: Project? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }

    /// `projects` arranged for the project picker: one group per top-level
    /// project, each carrying its direct children — only one level deep
    /// (matching the design mockup's picker, which doesn't nest grandchildren)
    /// rather than `ProjectsListViewModel`'s fully recursive tree.
    public var projectGroups: [ProjectGroup] {
        let childrenByParentID = Dictionary(grouping: projects, by: \.parentProjectID)
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

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
    }

    public func load() async {
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            projects = try await projectRepository.fetchProjects()
                .filter { !$0.isArchived }
                .sorted { $0.position < $1.position }
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    /// Creates the task from the current form state. Leaves `title`/
    /// `selectedProjectID`/`priority` untouched on success so the caller
    /// (the sheet) decides what happens next — typically dismissing.
    @discardableResult
    public func save() async -> VikunjaTask? {
        guard canSave, let selectedProjectID else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }
        do {
            let created = try await taskRepository.create(
                VikunjaTask(
                    id: 0,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    priority: priority,
                    projectID: selectedProjectID
                )
            )
            toastPresenter.show("Task created", style: .success)
            return created
        } catch let error as VikunjaError {
            saveErrorMessage = error.displayMessage
            return nil
        } catch {
            saveErrorMessage = error.localizedDescription
            return nil
        }
    }
}
