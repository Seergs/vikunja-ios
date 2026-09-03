import Foundation
import Observation
import VikunjaCore

/// Drives the Calendar screen: the account's tasks across every project, which
/// `CalendarView` lays out on a month grid by due date. Like the Today screen,
/// nothing scopes the fetch to one project — every project's tasks are pulled
/// and merged.
@MainActor
@Observable
public final class CalendarViewModel {
    public private(set) var tasks: [VikunjaTask] = []
    /// Looked up per row/dot for the project color, since a task only carries
    /// its `projectID`.
    public private(set) var projectsByID: [Int: Project] = [:]
    public private(set) var loadState: ScreenLoadState = .idle

    public var isLoading: Bool {
        loadState == .loading
    }

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let hapticPresenter: HapticFeedbackPresenting

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        hapticPresenter: HapticFeedbackPresenting = NoopHapticFeedback(),
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.hapticPresenter = hapticPresenter
    }

    /// Skips the `.loading` transition when content is already loaded (a
    /// pull-to-refresh), so the grid doesn't swap out for a spinner mid-refresh
    /// — same reasoning as `TodayViewModel.load()`.
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
    /// whole screen — mirrors `TodayViewModel.fetchAllTasks`.
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

    /// Flips a task's completion state, persists it, and rolls the local flip
    /// back if the server rejects it — so a failed request never leaves a row
    /// showing a state the server doesn't have.
    public func toggleDone(_ task: VikunjaTask) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.isDone.toggle()
        tasks[index] = updated
        if updated.isDone {
            hapticPresenter.play(.success)
        }
        do {
            tasks[index] = try await taskRepository.update(updated)
        } catch {
            tasks[index] = task
        }
    }
}
