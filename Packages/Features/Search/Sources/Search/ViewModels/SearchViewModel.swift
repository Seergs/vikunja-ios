import Foundation
import Observation
import VikunjaCore

@Observable
@MainActor
public final class SearchViewModel {
    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let toastPresenter: ToastPresenting

    var query = ""
    var state = ScreenLoadState<[VikunjaTask]>.idle
    var projectsByID: [Int: Project] = [:]

    private var lastSearchQuery = ""
    private var isSearching = false

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        toastPresenter: ToastPresenting
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.toastPresenter = toastPresenter
    }

    public func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        if trimmedQuery.isEmpty {
            state = .idle
            return
        }

        if trimmedQuery == lastSearchQuery && isSearching {
            return
        }

        lastSearchQuery = trimmedQuery
        isSearching = true
        state = .loading

        do {
            let tasks = try await taskRepository.searchTasks(query: trimmedQuery)

            let projectIDs = Set(tasks.compactMap { $0.projectID })
            await loadProjects(ids: Array(projectIDs))

            state = .loaded(tasks)
            isSearching = false
        } catch {
            state = .failure((error as? VikunjaError)?.displayMessage ?? "Search failed")
            isSearching = false
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
