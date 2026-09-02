import SwiftUI
import VikunjaCore

public extension SensoryFeedback {
    /// Maps the design system's semantic `HapticStyle` onto SwiftUI's
    /// `.sensoryFeedback` vocabulary, so a view-driven haptic uses the exact
    /// same style names a ViewModel uses through `HapticFeedbackPresenting`.
    init(_ style: HapticStyle) {
        switch style {
        case .success: self = .success
        case .warning: self = .warning
        case .error: self = .error
        case .selection: self = .selection
        case .light: self = .impact(weight: .light)
        case .medium: self = .impact(weight: .medium)
        case .heavy: self = .impact(weight: .heavy)
        case .soft: self = .impact(flexibility: .soft)
        case .rigid: self = .impact(flexibility: .rigid)
        }
    }
}

public extension View {
    /// Fires a haptic whenever `trigger` changes value. A thin wrapper over
    /// `.sensoryFeedback(_:trigger:)` that keeps a purely view-driven tap a
    /// one-liner and locks the style vocabulary to `HapticStyle`.
    ///
    /// ```swift
    /// Toggle("Done", isOn: $isDone)
    ///     .vikunjaHaptic(.success, trigger: isDone)
    /// ```
    ///
    /// When the *decision* to tap lives in a ViewModel (e.g. an optimistic
    /// update that may roll back), inject `HapticFeedbackPresenting` there
    /// instead and call `play(_:)`.
    func vikunjaHaptic(_ style: HapticStyle, trigger: some Equatable) -> some View {
        sensoryFeedback(SensoryFeedback(style), trigger: trigger)
    }

    /// As `vikunjaHaptic(_:trigger:)`, but only taps when `condition` returns
    /// `true` for the old/new pair — e.g. tap on completing a task but not on
    /// un-completing it.
    func vikunjaHaptic<T: Equatable>(
        _ style: HapticStyle,
        trigger: T,
        condition: @escaping (_ oldValue: T, _ newValue: T) -> Bool,
    ) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in
            condition(old, new) ? SensoryFeedback(style) : nil
        }
    }
}
