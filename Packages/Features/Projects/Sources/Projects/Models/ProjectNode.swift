import VikunjaCore

/// A project positioned within its parent/child hierarchy, ready for display.
/// View-specific projection of `Project` — not a domain model itself.
public struct ProjectNode: Identifiable, Equatable, Sendable {
    public let project: Project
    public let children: [ProjectNode]

    public var id: Int { project.id }

    public init(project: Project, children: [ProjectNode] = []) {
        self.project = project
        self.children = children
    }
}
