import Foundation
import VikunjaCore

/// On-device cache of each account's Vikunja default project
/// (`settings.default_project_id` from `GET /api/v1/user`). It's a plain
/// preference, not a credential, so `UserDefaults` is the right home — the
/// Keychain rule is for secrets only.
///
/// `AppContainer` refreshes it once per app launch (and on account switch);
/// quick-add reads it synchronously, so opening the sheet never waits on the
/// network for the default project. Keyed by account id, so switching
/// instances picks up that instance's own default.
struct DefaultProjectStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(for accountID: UUID) -> String {
        "defaultProjectID.\(accountID.uuidString)"
    }

    /// The cached default project id for the account, or `nil` if none is
    /// stored (or the stored value is Vikunja's "unset" sentinel, `0`).
    func projectID(forAccountID accountID: UUID) -> Int? {
        let stored = defaults.integer(forKey: key(for: accountID))
        return stored == 0 ? nil : stored
    }

    func setProjectID(_ projectID: Int?, forAccountID accountID: UUID) {
        if let projectID, projectID != 0 {
            defaults.set(projectID, forKey: key(for: accountID))
        } else {
            defaults.removeObject(forKey: key(for: accountID))
        }
    }
}
