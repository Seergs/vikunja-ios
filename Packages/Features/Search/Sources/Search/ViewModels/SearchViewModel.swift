import Foundation
import Observation
import VikunjaCore

@Observable
@MainActor
public final class SearchViewModel {
    /// How long to wait after the last keystroke before hitting the network, so
    /// typing doesn't fire (and re-render) a request per character.
    static let debounceInterval: Duration = .milliseconds(300)

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting
    private let hapticPresenter: HapticFeedbackPresenting

    var query = ""
    var state = ScreenLoadState<[VikunjaTask]>.idle
    var projectsByID: [Int: Project] = [:]

    private var lastSearchQuery = ""
    private var searchTask: Task<Void, Never>?

    /// Whether the account's project list has been fetched at least once this
    /// view-model lifetime. Projects only feed each row's name/color badge and
    /// barely change during a search session, so the list is fetched once and
    /// reused instead of re-downloaded on every debounced search.
    private var projectsLoaded = false

    /// Set once the "could not load project details" toast has been shown, so a
    /// burst of searches against a failing `/projects` endpoint doesn't queue
    /// one identical error toast per keystroke. Reset on the next success.
    private var didWarnProjectLoadFailure = false

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting,
        hapticPresenter: HapticFeedbackPresenting = NoopHapticFeedback(),
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
        self.hapticPresenter = hapticPresenter
    }

    /// Called on every change to `query`. Debounces, then searches.
    public func queryChanged() {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        if trimmedQuery.isEmpty {
            lastSearchQuery = ""
            state = .idle
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmedQuery)
        }
    }

    /// Warms the project cache when the Search screen appears, so the first
    /// search doesn't have to wait on the project list at all.
    public func preload() async {
        await loadProjects()
    }

    private func performSearch(_ trimmedQuery: String) async {
        guard trimmedQuery != lastSearchQuery || !state.isLoaded else { return }

        // Keep the current results on screen while re-searching; only fall back
        // to the full-screen spinner when there's nothing to show yet. This is
        // what stops the list from flickering away on every keystroke.
        if !state.isLoaded {
            state = .loading
        }

        do {
            // Load the project list concurrently with the search rather than
            // after it. Once cached, `loadProjects()` returns immediately, so
            // repeat searches only cost the one task-search request.
            async let projectsReady: Void = loadProjects()
            let tasks = try await taskRepository.searchTasks(query: trimmedQuery)
            guard !Task.isCancelled else { return }
            await projectsReady
            guard !Task.isCancelled else { return }

            // A task pointing at a project created since the list was cached:
            // refresh once so its row can render instead of being dropped by
            // the `if let project` lookup in the view.
            if tasks.contains(where: { projectsByID[$0.projectID] == nil }) {
                await loadProjects(force: true)
                guard !Task.isCancelled else { return }
            }

            // Only advance `lastSearchQuery` once the search actually landed, so
            // a cancelled or failed query can be retried instead of being
            // suppressed by the dedupe guard above while stale results show.
            lastSearchQuery = trimmedQuery
            state = .loaded(tasks)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failure((error as? VikunjaError)?.displayMessage ?? "Search failed")
        }
    }

    public func toggleDone(_ task: VikunjaTask) async {
        var updated = task
        updated.isDone.toggle()
        if updated.isDone {
            hapticPresenter.play(.success)
        }

        do {
            let response = try await taskRepository.update(updated)
            if case var .loaded(tasks) = state {
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index] = response
                    state = .loaded(tasks)
                }
            }
        } catch {
            toastPresenter.show((error as? VikunjaError)?.displayMessage ?? "Update failed", style: .error)
        }
    }

    public func delete(_ task: VikunjaTask) async {
        do {
            try await taskRepository.delete(id: task.id)
            if case var .loaded(tasks) = state {
                tasks.removeAll { $0.id == task.id }
                state = .loaded(tasks)
            }
            toastPresenter.show("Task deleted", style: .success)
        } catch {
            toastPresenter.show((error as? VikunjaError)?.displayMessage ?? "Delete failed", style: .error)
        }
    }

    /// Fetches the account's project list into `projectsByID`. A no-op once the
    /// list has been loaded, unless `force` is set (used when a search result
    /// references a project the cache hasn't seen yet).
    private func loadProjects(force: Bool = false) async {
        guard force || !projectsLoaded else { return }
        do {
            let projects = try await projectRepository.fetchProjects()
            for project in projects {
                projectsByID[project.id] = project
            }
            projectsLoaded = true
            didWarnProjectLoadFailure = false
        } catch {
            guard !Task.isCancelled else { return }
            if !didWarnProjectLoadFailure {
                toastPresenter.show("Could not load project details", style: .error)
                didWarnProjectLoadFailure = true
            }
        }
    }
}
