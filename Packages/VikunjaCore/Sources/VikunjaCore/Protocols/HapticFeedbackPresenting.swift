/// What a ViewModel needs in order to fire a haptic, without knowing anything
/// about the Taptic Engine or UIKit. Implemented by `VikuDesignSystem`'s
/// `HapticFeedbackCenter` and injected via `AppContainer`, the same way
/// `ToastPresenting` and the repository protocols are — so playing a haptic
/// from a ViewModel never requires importing `VikuDesignSystem` or any
/// UIKit/SwiftUI type.
///
/// A pure SwiftUI view that just wants a haptic when some state changes should
/// use `View.vikunjaHaptic(_:trigger:)` from `VikuDesignSystem` instead —
/// no injection needed. Reach for this protocol when the *decision* to tap
/// lives in a ViewModel (an optimistic toggle that rolled back, a create that
/// succeeded).
@MainActor
public protocol HapticFeedbackPresenting {
    /// Plays the tap for `style` now.
    func play(_ style: HapticStyle)

    /// Warms up the Taptic Engine so the next matching `play(_:)` fires
    /// without the first-call latency (~tens of ms). Optional — safe to call
    /// repeatedly, and a no-op by default. Call it when a haptic is likely
    /// imminent (a drag gesture begins, a confirming sheet appears).
    func prepare(_ style: HapticStyle)
}

public extension HapticFeedbackPresenting {
    func prepare(_ style: HapticStyle) {}
}

/// A `HapticFeedbackPresenting` that does nothing. The default for previews
/// and tests (haptics are never asserted), and the environment fallback when
/// no real engine is injected.
public struct NoopHapticFeedback: HapticFeedbackPresenting {
    public init() {}
    public func play(_ style: HapticStyle) {}
}
