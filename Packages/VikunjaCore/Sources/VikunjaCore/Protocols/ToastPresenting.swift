/// What a ViewModel needs in order to surface a toast, without knowing
/// anything about how or where it's rendered. Implemented by
/// `VikuDesignSystem`'s `ToastCenter` and injected via `AppContainer`, the
/// same way repository protocols are — so showing a toast from a ViewModel
/// never requires importing `VikuDesignSystem` or any SwiftUI type.
@MainActor
public protocol ToastPresenting {
    func show(_ message: String, style: ToastStyle)
}

public extension ToastPresenting {
    /// Convenience for the common case: a neutral, informational toast.
    func show(_ message: String) {
        show(message, style: .info)
    }
}
