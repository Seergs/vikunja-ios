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
        do {
            task = try await repository.update(task)
        } catch {
            task = previous
        }
    }
}
