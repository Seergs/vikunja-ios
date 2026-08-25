import SwiftUI

/// Color tokens. Values that originate as `oklch(...)` in the design source are
/// pre-converted to sRGB hex once here, rather than converting at runtime.
public enum VikunjaColor {
    public static let brandPrimary = Color(hex: 0x196AFF)

    public enum Priority {
        public static let urgent = Color(hex: 0xDF202E)
        public static let high = Color(hex: 0xE85E00)
        /// Kept as its own literal (matches `brandPrimary` today) so a future brand
        /// color change doesn't silently change this token too.
        public static let medium = Color(hex: 0x196AFF)
        public static let low = Color(hex: 0x79818D)
    }
}
