import Observation
import SwiftUI

/// Per-feature navigation state: the `NavigationPath` behind a feature's own
/// `NavigationStack`, plus the push/pop vocabulary features use instead of
/// reaching for `NavigationPath` directly. Every `Features/<Name>` module owns
/// one, typed to its own `Route` enum — this is what keeps navigation state
/// local to a feature instead of leaking into the app target.
@Observable
@MainActor
public final class Router<Route: Hashable> {
    public var path = NavigationPath()

    public init() {}

    public func push(_ route: Route) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path = NavigationPath()
    }
}
