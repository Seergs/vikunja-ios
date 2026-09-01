#if canImport(AppIntents)
import AppIntents
import VikunjaNavigation

/// Opens the app's quick-add task sheet. Backs the Siri shortcut
/// (`VikunjaShortcuts`, in the app target) and the Control Center control
/// (`QuickAddControl`), and shows up in the Shortcuts app on its own.
///
/// `openAppWhenRun` is true, so the system foregrounds the app and runs
/// `perform()` in its process. The app registers its `DeepLinkRouter` with
/// `AppDependencyManager` at launch, so `perform()` can hand off through the
/// exact same route a `vikunja://quick-add` URL takes.
public struct OpenQuickAddIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Task"
    public static let description = IntentDescription("Opens Vikunja's quick-add sheet to jot down a new task.")
    public static let openAppWhenRun = true

    @Dependency private var deepLinkRouter: DeepLinkRouter

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        deepLinkRouter.open(.quickAdd(projectID: nil))
        return .result()
    }
}
#endif
