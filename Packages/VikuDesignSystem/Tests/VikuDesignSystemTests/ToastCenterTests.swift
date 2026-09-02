import Testing
import VikunjaCore
@testable import VikuDesignSystem

@MainActor
struct ToastCenterTests {
    @Test
    func `show presents immediately when idle`() {
        let center = ToastCenter()

        center.show("Task created", style: .success)

        #expect(center.current?.message == "Task created")
        #expect(center.current?.style == .success)
    }

    @Test
    func `second toast queues until the first is dismissed`() {
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
    func `toast presenting defaults to info style`() {
        let center = ToastCenter()
        let presenter: ToastPresenting = center

        presenter.show("Heads up")

        #expect(center.current?.style == .info)
    }
}
