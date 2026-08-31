import Foundation
import Observation
import VikunjaWidgetKit

/// A URL the app was opened with, parsed into an in-app destination. Today the
/// only case is quick-add — opened from the Today widget's "add" button, from
/// Shortcuts, or any other `vikunja://quick-add` caller. `today`/`task` links
/// will be added here once their in-app routing exists.
enum DeepLink: Equatable {
    /// `vikunja://quick-add` (optionally `?project=<id>`) — present the
    /// tab-bar quick-add sheet, defaulting to the given project when supplied.
    case quickAdd(projectID: Int?)

    init?(url: URL) {
        guard url.scheme?.lowercased() == VikunjaWidgetConfig.urlScheme else { return nil }
        // A custom-scheme URL puts its first segment in `host`
        // (`vikunja://quick-add` → host "quick-add", not a path component).
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch components?.host {
        case "quick-add":
            let project = components?.queryItems?.first { $0.name == "project" }?.value
            self = .quickAdd(projectID: project.flatMap(Int.init))
        default:
            return nil
        }
    }
}

/// Holds the deep link the app was last opened with until a screen is mounted
/// and ready to act on it: set from `RootView`'s `.onOpenURL`, consumed by
/// `QuickAddOverlay`. Lives on `AppContainer` rather than in view `@State` so a
/// link that arrives during a cold launch — before the tab shell exists —
/// survives until the shell is up. Injected the same way `QuickAddContext` is.
@MainActor
@Observable
final class DeepLinkRouter {
    private(set) var pending: DeepLink?

    func open(_ link: DeepLink) {
        pending = link
    }

    /// Clears `pending` once a screen has acted on it, so it doesn't re-fire
    /// the next time that screen appears.
    func clear() {
        pending = nil
    }
}
