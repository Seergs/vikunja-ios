import SwiftUI
import Testing
@testable import VikunjaDesignSystem

struct ColorHexTests {
    @Test
    func hexInitializerMatchesComponents() {
        let color = Color(hex: 0x196AFF)

        #expect(color.resolve(in: .init()) == Color(.sRGB, red: 0x19 / 255, green: 0x6A / 255, blue: 0xFF / 255).resolve(in: .init()))
    }
}
