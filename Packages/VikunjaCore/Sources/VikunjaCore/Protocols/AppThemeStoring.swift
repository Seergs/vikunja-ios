/// What a ViewModel (or view) needs in order to read and change the user's
/// theme preference, without knowing anything about where it's persisted or
/// rendered. Implemented by `VikuDesignSystem`'s `ThemeCenter` and injected
/// via `AppContainer`, the same way `ToastPresenting` is.
@MainActor
public protocol AppThemeStoring: AnyObject {
    var theme: AppTheme { get }
    func setTheme(_ theme: AppTheme)
}
