import Foundation
import Observation
import VikunjaCore

/// Drives the projects list screen: loads the flat project list from the
/// server and arranges it into a parent/child tree by `parentProjectID`,
/// ready for a hierarchical view to render.
@MainActor
@Observable
public final class ProjectsListViewModel {
    public private(set) var rootNodes: [ProjectNode] = []
    public private(set) var loadState: ScreenLoadState = .idle

    public var isLoading: Bool { loadState == .loading }

    private let repository: ProjectRepositoryProtocol

    public init(repository: ProjectRepositoryProtocol) {
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
            let projects = try await repository.fetchProjects()
            rootNodes = Self.tree(from: projects)
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    /// Builds the parent/child tree for every non-archived project, ordered
    /// by `position` within each level. Guards against a cyclic
    /// `parentProjectID` (malformed server data) by never revisiting a
    /// project id on the same branch.
    static func tree(from projects: [Project]) -> [ProjectNode] {
        let visible = projects.filter { !$0.isArchived }
        let childrenByParentID = Dictionary(grouping: visible, by: \.parentProjectID)

        func nodes(withParentID parentID: Int?, excluding ancestorIDs: Set<Int>) -> [ProjectNode] {
            (childrenByParentID[parentID] ?? [])
                .sorted { $0.position < $1.position }
                .compactMap { project in
                    guard !ancestorIDs.contains(project.id) else { return nil }
                    let children = nodes(withParentID: project.id, excluding: ancestorIDs.union([project.id]))
                    return ProjectNode(project: project, children: children)
                }
        }

        return nodes(withParentID: nil, excluding: [])
    }
}
