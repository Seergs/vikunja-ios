import Testing
import VikunjaCore
@testable import VikunjaDesignSystem

@MainActor
struct ToastCenterTests {
    @Test
    func showPresentsImmediatelyWhenIdle() {
        let center = ToastCenter()

        center.show("Task created", style: .success)

        #expect(center.current?.message == "Task created")
        #expect(center.current?.style == .success)
    }

    @Test
    func secondToastQueuesUntilTheFirstIsDismissed() {
        let center = ToastCenter()

        center.show("First")
        center.show("Second")
        #expect(center.current?.message == "First")

        center.dismissCurrent()
        #expect(center.current?.message == "Second")

        center.dismissCurrent()
        #expect(center.current == nil)
    }

    @Test
    func toastPresentingDefaultsToInfoStyle() {
        let center = ToastCenter()
        let presenter: ToastPresenting = center

        presenter.show("Heads up")

        #expect(center.current?.style == .info)
    }
}
