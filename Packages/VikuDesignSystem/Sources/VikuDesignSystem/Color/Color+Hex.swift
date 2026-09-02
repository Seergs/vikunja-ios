import SwiftUI

extension Color {
    /// Builds a `Color` from a `0xRRGGBB` literal, e.g. `Color(hex: 0x196AFF)`.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue)
    }

    /// Parses a Vikunja API `hex_color` value (`"RRGGBB"`, with or without a
    /// leading `#`) as it comes back on `Project`/`Label`. Returns `nil` for
    /// the empty string (no color set server-side) or anything malformed,
    /// so callers can fall back to a design-system default.
    public init?(vikunjaHex hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
