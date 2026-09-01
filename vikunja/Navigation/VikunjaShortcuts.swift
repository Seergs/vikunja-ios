import AppIntents
import VikunjaWidgetKit

/// Siri / Spotlight / Action Button phrases for the app's App Intents. The
/// system discovers these from the app bundle at install time, so an
/// `AppShortcutsProvider` has to live in the app target rather than a package.
struct VikunjaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenQuickAddIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "New \(.applicationName) task",
                "Quick add in \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill",
        )
    }
}
