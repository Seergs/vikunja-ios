import Foundation
import VikuNavigation
import VikunjaWidgetKit

extension DeepLink {
    /// Parses a `viku://` URL the app was opened with. `nil` for anything
    /// that isn't a recognized route. `DeepLink` itself lives in
    /// `VikuNavigation` (so `VikunjaWidgetKit`'s App Intents can build one);
    /// only this URL bridge needs the `viku` scheme string.
    init?(url: URL) {
        guard url.scheme?.lowercased() == VikunjaWidgetConfig.urlScheme else { return nil }
        // A custom-scheme URL puts its first segment in `host`
        // (`viku://quick-add` → host "quick-add", not a path component).
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
