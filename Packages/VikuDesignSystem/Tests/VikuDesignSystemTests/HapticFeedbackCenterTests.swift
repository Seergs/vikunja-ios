import SwiftUI
import Testing
import VikunjaCore
@testable import VikuDesignSystem

@MainActor
struct HapticFeedbackCenterTests {
    @Test
    func `plays and prepares every style without crashing`() {
        let center = HapticFeedbackCenter()
        for style in HapticStyle.allCases {
            center.prepare(style)
            center.play(style)
        }
    }

    @Test
    func `maps every style onto a SensoryFeedback value`() {
        // Compiles only while the `SensoryFeedback(_:)` switch stays
        // exhaustive; runs to confirm no case traps at runtime.
        for style in HapticStyle.allCases {
            _ = SensoryFeedback(style)
        }
    }
}
