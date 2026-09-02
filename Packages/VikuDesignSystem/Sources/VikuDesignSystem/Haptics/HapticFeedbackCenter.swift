import VikunjaCore

#if canImport(UIKit)
import UIKit
#endif

/// The app's Taptic Engine. One instance lives for the whole app — created
/// once by the composition root (`AppContainer.hapticCenter`) — and is handed
/// to any ViewModel that needs to fire a haptic, typed as
/// `HapticFeedbackPresenting` so the ViewModel never imports this package.
/// Mirrors `ToastCenter`'s relationship to `ToastPresenting`.
///
/// Generators are created lazily and kept alive between calls, which is what
/// lets `prepare(_:)` actually reduce latency: a fresh generator per call
/// would defeat the warm-up. On any platform without UIKit (macOS unit-test
/// host) every method is an inert no-op.
@MainActor
public final class HapticFeedbackCenter: HapticFeedbackPresenting {
    #if canImport(UIKit)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    private var impacts: [HapticStyle: UIImpactFeedbackGenerator] = [:]
    #endif

    public init() {}

    public func play(_ style: HapticStyle) {
        #if canImport(UIKit)
        switch style {
        case .success: notification.notificationOccurred(.success)
        case .warning: notification.notificationOccurred(.warning)
        case .error: notification.notificationOccurred(.error)
        case .selection: selection.selectionChanged()
        case .light, .medium, .heavy, .soft, .rigid:
            impactGenerator(for: style).impactOccurred()
        }
        #endif
    }

    public func prepare(_ style: HapticStyle) {
        #if canImport(UIKit)
        switch style {
        case .success, .warning, .error: notification.prepare()
        case .selection: selection.prepare()
        case .light, .medium, .heavy, .soft, .rigid: impactGenerator(for: style).prepare()
        }
        #endif
    }

    #if canImport(UIKit)
    private func impactGenerator(for style: HapticStyle) -> UIImpactFeedbackGenerator {
        if let existing = impacts[style] {
            return existing
        }
        let generator = UIImpactFeedbackGenerator(style: Self.uiKitStyle(for: style))
        impacts[style] = generator
        return generator
    }

    private static func uiKitStyle(for style: HapticStyle) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch style {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .soft: .soft
        case .rigid: .rigid
        // Non-impact styles never reach here — they don't use an impact generator.
        case .success, .warning, .error, .selection: .medium
        }
    }
    #endif
}
