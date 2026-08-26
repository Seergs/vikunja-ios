import Observation
import VikunjaCore

/// Drives the "create project" sheet: title only, matching Vikunja's minimum
/// required field for a new project. `parentProjectID` is fixed at
/// construction by the caller — set when the sheet is opened from within a
/// project's overview (creating a subproject) and left `nil` when opened from
/// the top-level projects list.
@MainActor
@Observable
public final class CreateProjectViewModel {
    public var title: String = ""
    public private(set) var isSaving: Bool = false
    public private(set) var saveErrorMessage: String?

    public let parentProjectID: Int?

    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
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

    /// Creates the project from the current form state. Leaves `title`
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
                    parentProjectID: parentProjectID
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
