/// The semantic category of a haptic tap. Purely descriptive — which Taptic
/// Engine pattern (notification / selection / impact) each case maps to is a
/// rendering concern owned by whatever implements `HapticFeedbackPresenting`,
/// not this type. Mirrors `ToastStyle`'s role for toasts.
///
/// Pick by meaning, not by feel:
/// - `.success` / `.warning` / `.error` — the outcome of an action the user
///   just took (a task saved, a guard tripped, a request failed).
/// - `.selection` — a discrete value changed under the user's finger
///   (a picker tick, a segmented control, a toggle).
/// - `.light` / `.medium` / `.heavy` / `.soft` / `.rigid` — a physical
///   "impact" for direct-manipulation moments (a drag snaps, a row commits,
///   a sheet detent catches). Weight/flexibility is the only axis.
public enum HapticStyle: Sendable, Equatable, CaseIterable {
    case success
    case warning
    case error
    case selection
    case light
    case medium
    case heavy
    case soft
    case rigid
}
