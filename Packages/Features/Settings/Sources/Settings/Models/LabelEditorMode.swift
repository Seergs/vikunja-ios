import VikunjaCore

/// Which of the two things `LabelEditorSheet` is doing: creating a brand-new
/// label, or editing an existing one. Presented as a `.sheet` by
/// `ManageLabelsView`, so — unlike `ConnectionFormMode` — this isn't a
/// `SettingsRoute` case.
enum LabelEditorMode: Identifiable, Hashable, Sendable {
    case create
    case edit(Label)

    var id: Int {
        switch self {
        case .create: return 0
        case let .edit(label): return label.id
        }
    }
}
