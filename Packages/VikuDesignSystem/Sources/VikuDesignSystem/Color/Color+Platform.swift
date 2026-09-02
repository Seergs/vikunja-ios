import SwiftUI

/// Platform-adaptive backgrounds backing `VikuColor.Surface`. Wrapped here so
/// the token file itself stays free of `#if os(...)` branching — this package
/// also builds for macOS to run its tests, where `UIColor` doesn't exist.
extension Color {
    static var platformCardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.1)
        #endif
    }

    static var platformFieldBackground: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemFill)
        #elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color.gray.opacity(0.15)
        #endif
    }

    /// The page canvas behind grouped content — what `.insetGrouped` lists
    /// use automatically, needed explicitly by a `.plain` list (paired with
    /// `.scrollContentBackground(.hidden)`) that hand-draws its own cards.
    static var platformPageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.gray.opacity(0.05)
        #endif
    }

    /// A darker, more legible secondary text color than `UIColor.secondaryLabel`
    /// — matches the design source's own gray scale rather than the system default.
    static var platformTextSecondary: Color {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.72, green: 0.73, blue: 0.75, alpha: 1)
                : UIColor(red: 0.29, green: 0.30, blue: 0.33, alpha: 1)
        })
        #elseif os(macOS)
        Color(nsColor: .secondaryLabelColor)
        #else
        Color.secondary
        #endif
    }

    static var platformTextTertiary: Color {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.49, green: 0.50, blue: 0.52, alpha: 1)
                : UIColor(red: 0.54, green: 0.55, blue: 0.58, alpha: 1)
        })
        #elseif os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color.secondary
        #endif
    }
}
