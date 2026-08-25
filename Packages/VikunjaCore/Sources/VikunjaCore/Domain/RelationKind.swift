import Foundation

/// The relation-kind strings Vikunja's API uses as keys in a task's
/// `related_tasks` map. `VikunjaTask.subtasks`/`dependsOn`/`blocks` cover
/// `subtask`/`blocked`/`blocking` directly, since those get distinct UI
/// treatment (checkboxes, the "Blocked" banner); every other kind is
/// surfaced generically through `VikunjaTask.otherRelations`.
public enum RelationKind: String, Sendable, CaseIterable, Hashable, Codable {
    case subtask
    case parenttask
    case related
    case duplicateof
    case duplicates
    case blocking
    case blocked
    case precedes
    case follows
    case copiedfrom
    case copiedto

    /// Section title shown in the UI for this relation kind.
    public var displayName: String {
        switch self {
        case .subtask: return "Subtasks"
        case .parenttask: return "Parent Task"
        case .related: return "Related Tasks"
        case .duplicateof: return "Duplicate Of"
        case .duplicates: return "Duplicates"
        case .blocking: return "Blocks"
        case .blocked: return "Depends On"
        case .precedes: return "Precedes"
        case .follows: return "Follows"
        case .copiedfrom: return "Copied From"
        case .copiedto: return "Copied To"
        }
    }
}
