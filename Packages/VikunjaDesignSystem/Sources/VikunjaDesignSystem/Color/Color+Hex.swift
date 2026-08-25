import SwiftUI

extension Color {
    /// Builds a `Color` from a `0xRRGGBB` literal, e.g. `Color(hex: 0x196AFF)`.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue)
    }
}
