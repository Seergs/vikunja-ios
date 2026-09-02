import Observation
import VikunjaCore

/// Owns the toast queue and drives what's currently on screen. One instance
/// lives for the whole app — created once by the composition root and
/// attached via `.toastHost(_:)` as high in the view hierarchy as possible —
/// and is handed to any ViewModel that needs to surface a toast, typed as
/// `ToastPresenting` so the ViewModel never imports this package. Toasts
/// queue rather than overlap: calling `show` while one is already up waits
/// its turn instead of interrupting it.
@Observable
@MainActor
public final class ToastCenter: ToastPresenting {
    public private(set) var current: Toast?

    private var queue: [Toast] = []
    private var dismissTask: Task<Void, Never>?

    public init() {}

    public func show(_ message: String, style: ToastStyle) {
        queue.append(Toast(message: message, style: style))
        advanceIfNeeded()
    }

    /// Dismisses whatever's currently shown and presents the next queued
    /// toast, if any. Called by the countdown timer, and by tap-to-dismiss.
    public func dismissCurrent() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
        advanceIfNeeded()
    }

    private func advanceIfNeeded() {
        guard current == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        current = next
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(next.duration))
            guard !Task.isCancelled else { return }
            self?.dismissCurrent()
        }
    }
}
