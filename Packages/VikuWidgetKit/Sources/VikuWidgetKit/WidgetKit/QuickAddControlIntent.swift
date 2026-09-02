#if canImport(AppIntents)
import AppIntents
import VikuNavigation

/// Opens the app's quick-add task sheet from the Control Center control
/// (`QuickAddControl`). Deliberately separate from the app target's
/// `OpenQuickAddIntent`: an App Intent type registered in both the app and this
/// extension breaks Siri's App Shortcut dispatch, so the Siri-facing intent
/// stays app-only and the control gets its own, hidden from Shortcuts.
///
/// `openAppWhenRun` is true, so `perform()` runs in the app's process, where
/// `DeepLinkRouter.shared` is the instance the UI observes.
public struct QuickAddControlIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Task"
    public static let description = IntentDescription("Opens Viku's quick-add sheet to jot down a new task.")
    public static let openAppWhenRun = true
    public static let isDiscoverable = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.open(.quickAdd(projectID: nil))
        return .result()
    }
}
#endif
