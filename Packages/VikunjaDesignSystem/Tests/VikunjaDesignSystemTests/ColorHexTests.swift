import SwiftUI
import Testing
@testable import VikunjaDesignSystem

struct ColorHexTests {
    @Test
    func `hex initializer matches components`() {
        let color = Color(hex: 0x196AFF)

        #expect(color.resolve(in: .init()) == Color(.sRGB, red: 0x19 / 255, green: 0x6A / 255, blue: 0xFF / 255).resolve(in: .init()))
    }

    @Test
    func `vikunja hex parses with or without leading hash`() {
        #expect(Color(vikunjaHex: "196AFF")?.resolve(in: .init()) == Color(hex: 0x196AFF).resolve(in: .init()))
        #expect(Color(vikunjaHex: "#196AFF")?.resolve(in: .init()) == Color(hex: 0x196AFF).resolve(in: .init()))
    }

    @Test
    func `vikunja hex returns nil for empty or malformed input`() {
        #expect(Color(vikunjaHex: "") == nil)
        #expect(Color(vikunjaHex: "not-a-color") == nil)
        #expect(Color(vikunjaHex: "FF") == nil)
    }
}
