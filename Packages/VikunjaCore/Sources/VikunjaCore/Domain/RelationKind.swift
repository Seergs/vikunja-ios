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
        case .subtask: "Subtasks"
        case .parenttask: "Parent Task"
        case .related: "Related Tasks"
        case .duplicateof: "Duplicate Of"
        case .duplicates: "Duplicates"
        case .blocking: "Blocks"
        case .blocked: "Depends On"
        case .precedes: "Precedes"
        case .follows: "Follows"
        case .copiedfrom: "Copied From"
        case .copiedto: "Copied To"
        }
    }
}
