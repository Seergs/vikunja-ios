import Observation
import VikunjaCore

/// Drives the "create project" sheet: title, color, and parent project
/// (defaulting to "None" — a root-level project). `parentProjectID` starts at
/// whatever the caller passed in at construction (set when the sheet is
/// opened from within a project's overview, to preset that project as the
/// parent) but stays user-editable via the picker, matching `Tasks`'
/// `QuickAddTaskViewModel`'s project picker.
@MainActor
@Observable
public final class CreateProjectViewModel {
    public var title: String = ""
    public var hexColor: String = ""
    public var parentProjectID: Int?
    public private(set) var projects: [Project] = []
    public private(set) var loadState: ScreenLoadState = .idle
    public private(set) var isSaving: Bool = false
    public private(set) var saveErrorMessage: String?

    public var isLoading: Bool { loadState == .loading }

    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    public var selectedParentProject: Project? {
        guard let parentProjectID else { return nil }
        return projects.first { $0.id == parentProjectID }
    }

    /// `projects` arranged for the parent-project picker: one group per
    /// top-level project, each carrying its direct children — only one level
    /// deep, the same shape `QuickAddTaskViewModel.projectGroups` uses for
    /// its project picker.
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

    private let repository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting

    public init(
        parentProjectID: Int? = nil,
        repository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting
    ) {
        self.parentProjectID = parentProjectID
        self.repository = repository
        self.toastPresenter = toastPresenter
    }

    /// Loads the existing projects the parent-project picker offers.
    public func load() async {
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            projects = try await repository.fetchProjects()
                .filter { !$0.isArchived }
                .sorted { $0.position < $1.position }
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    /// Creates the project from the current form state. Leaves the form
    /// untouched on success so the caller (the sheet) decides what happens
    /// next — typically dismissing.
    @discardableResult
    public func save() async -> Project? {
        guard canSave else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }
        do {
            let created = try await repository.create(
                Project(
                    id: 0,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    parentProjectID: parentProjectID,
                    hexColor: hexColor
                )
            )
            toastPresenter.show("Project created", style: .success)
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
