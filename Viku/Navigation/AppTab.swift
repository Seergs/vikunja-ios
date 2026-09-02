import Foundation

/// The app's top-level tabs. Lives in the app target (not a Feature or a
/// package) because it's the one thing that legitimately needs to know about
/// every feature's tab at once — `MainTabView` is the only consumer.
enum AppTab: Hashable, CaseIterable, Identifiable {
    case home
    case projects
    case search
    case settings

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .home: "Today"
        case .projects: "Projects"
        case .search: "Search"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "calendar.badge.checkmark"
        case .projects: "square.grid.2x2"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}
