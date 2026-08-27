/// A project's own task-completion tally (`done` of `total`), used for the
/// progress indicators on the projects list rows and the subproject cards.
/// View-specific projection — not a domain model.
public struct ProjectTaskSummary: Equatable, Sendable {
    public let done: Int
    public let total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }

    /// Completion as a 0...1 fraction, `0` when the project has no tasks.
    public var fraction: Double {
        total > 0 ? Double(done) / Double(total) : 0
    }
}
