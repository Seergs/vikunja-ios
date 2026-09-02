import Observation

/// An external entry point resolved into an in-app destination. Today the only
/// case is quick-add — reached from the Today widget's "add" button, a
/// `viku://quick-add` URL (Shortcuts, other apps), the Siri shortcut, or a
/// Control Center control. `today`/`task` links will be added here once their
/// in-app routing exists.
///
/// URL parsing lives in the app target (`DeepLink.init?(url:)`), since the
/// `viku` scheme string is defined in `VikuWidgetKit`; this enum stays
/// dependency-free so `VikuWidgetKit`'s App Intents can build one directly.
public enum DeepLink: Equatable, Sendable {
    /// Present the tab-bar quick-add sheet, defaulting to the given project
    /// when supplied.
    case quickAdd(projectID: Int?)
}

/// Holds the deep link the app was last opened with until a screen is mounted
/// and ready to act on it: set from `RootView`'s `.onOpenURL` or an App
/// Intent's `perform()`, consumed by `QuickAddOverlay`. Not view `@State`, so a
/// link that arrives during a cold launch — before the tab shell exists —
/// survives until the shell is up.
///
/// A process-wide singleton (`shared`) rather than a `@Dependency`:
/// `OpenQuickAddIntent` sets `openAppWhenRun`, so its `perform()` runs in the
/// app's process and touches the same instance the UI observes, with no
/// registration-timing window to lose an invocation in.
@Observable
@MainActor
public final class DeepLinkRouter {
    public static let shared = DeepLinkRouter()

    public private(set) var pending: DeepLink?

    public init() {}

    public func open(_ link: DeepLink) {
        pending = link
    }

    /// Clears `pending` once a screen has acted on it, so it doesn't re-fire
    /// the next time that screen appears.
    public func clear() {
        pending = nil
    }
}
