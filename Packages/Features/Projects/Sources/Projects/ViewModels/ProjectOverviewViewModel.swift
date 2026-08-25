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
    public private(set) var tasks: [VikunjaTask] = []
    public private(set) var loadState: ScreenLoadState = .idle

    public var isLoading: Bool { loadState == .loading }

    private let repository: TaskRepositoryProtocol

    public init(project: Project, repository: TaskRepositoryProtocol) {
        self.project = project
        self.repository = repository
    }

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
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }
}
