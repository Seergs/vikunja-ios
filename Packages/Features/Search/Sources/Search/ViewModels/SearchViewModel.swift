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

    var query = ""
    var state = ScreenLoadState<[VikunjaTask]>.idle
    var projectsByID: [Int: Project] = [:]

    private var lastSearchQuery = ""
    private var searchTask: Task<Void, Never>?

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
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

    private func performSearch(_ trimmedQuery: String) async {
        guard trimmedQuery != lastSearchQuery || !state.isLoaded else { return }
        lastSearchQuery = trimmedQuery

        // Keep the current results on screen while re-searching; only fall back
        // to the full-screen spinner when there's nothing to show yet. This is
        // what stops the list from flickering away on every keystroke.
        if !state.isLoaded {
            state = .loading
        }

        do {
            let tasks = try await taskRepository.searchTasks(query: trimmedQuery)
            guard !Task.isCancelled else { return }

            let projectIDs = Set(tasks.map { $0.projectID })
            await loadProjects(ids: Array(projectIDs))
            guard !Task.isCancelled else { return }

            state = .loaded(tasks)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failure((error as? VikunjaError)?.displayMessage ?? "Search failed")
        }
    }

    public func toggleDone(_ task: VikunjaTask) async {
        var updated = task
        updated.isDone.toggle()

        do {
            let response = try await taskRepository.update(updated)
            if case .loaded(var tasks) = state {
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
            if case .loaded(var tasks) = state {
                tasks.removeAll { $0.id == task.id }
                state = .loaded(tasks)
            }
            toastPresenter.show("Task deleted", style: .success)
        } catch {
            toastPresenter.show((error as? VikunjaError)?.displayMessage ?? "Delete failed", style: .error)
        }
    }

    private func loadProjects(ids: [Int]) async {
        do {
            let projects = try await projectRepository.fetchProjects()
            for project in projects {
                projectsByID[project.id] = project
            }
        } catch {
            toastPresenter.show("Could not load project details", style: .error)
        }
    }
}
