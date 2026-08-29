import Foundation

struct BuildConfig {
    static var isDevBuild: Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        return bundleID.contains(".dev")
    }
}
