import Foundation
import Testing
@testable import VikuDesignSystem
import VikunjaCore

@MainActor
struct ThemeCenterTests {
    private func makeDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: "ThemeCenterTests.\(UUID().uuidString)") else {
            fatalError("Failed to create an in-memory UserDefaults suite for testing")
        }
        return defaults
    }

    @Test
    func `defaults to system when nothing is stored`() {
        let center = ThemeCenter(defaults: makeDefaults())

        #expect(center.theme == .system)
        #expect(center.colorScheme == nil)
    }

    @Test
    func `setTheme persists and updates colorScheme`() {
        let defaults = makeDefaults()
        let center = ThemeCenter(defaults: defaults)

        center.setTheme(.dark)

        #expect(center.theme == .dark)
        #expect(center.colorScheme == .dark)
        #expect(defaults.string(forKey: "appTheme") == "dark")
    }

    @Test
    func `a new instance reads back the persisted theme`() {
        let defaults = makeDefaults()
        ThemeCenter(defaults: defaults).setTheme(.light)

        let reloaded = ThemeCenter(defaults: defaults)

        #expect(reloaded.theme == .light)
        #expect(reloaded.colorScheme == .light)
    }

    @Test
    func `app theme storing protocol exposes the same theme`() {
        let center = ThemeCenter(defaults: makeDefaults())
        let storing: AppThemeStoring = center

        storing.setTheme(.dark)

        #expect(storing.theme == .dark)
    }
}
