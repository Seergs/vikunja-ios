import Foundation

/// Shared identifiers the app target and the widget extension must agree on.
/// These must match the App Group and `keychain-access-group` entries in both
/// targets' entitlements, and `accountStoreService` must match the `service`
/// the app's `KeychainAccountStore` is constructed with.
public enum VikunjaWidgetConfig {
    /// App Group container, used only for the cached Today snapshot. Add this
    /// exact group to the App Groups capability of both the app target and the
    /// widget extension.
    public static let appGroupIdentifier = "group.dev.sergiosuarez.vikunja"

    /// Shared keychain group holding the account index, the active-account
    /// pointer, and each account's bearer token. List
    /// `$(AppIdentifierPrefix)dev.sergiosuarez.vikunja.shared` under
    /// Keychain Sharing in both targets' entitlements; the runtime prepends
    /// the team prefix, so the code passes only the suffix.
    public static let keychainAccessGroup = "dev.sergiosuarez.vikunja.shared"

    /// Must match the `service:` passed to `KeychainAccountStore` in the app's
    /// `AppContainer` (its default, today).
    public static let accountStoreService = "dev.sergiosuarez.vikunja.accounts"

    /// `kind` string tying `TodayWidget` to `WidgetCenter.reloadTimelines(ofKind:)`.
    public static let todayWidgetKind = "TodayWidget"

    /// URL scheme the widget deep-links back into the app with
    /// (`vikunja://today`, `vikunja://task/<id>`). Register it under the app
    /// target's URL Types.
    public static let urlScheme = "vikunja"

    /// How many task rows the snapshot carries — enough for `.systemLarge`,
    /// keeping the cached payload and the extension's memory footprint small.
    public static let taskLimit = 8

    /// Minimum spacing between timeline refreshes. WidgetKit only grants a
    /// bounded number of refreshes per day, so this stays coarse.
    public static let refreshInterval: TimeInterval = 30 * 60
}
