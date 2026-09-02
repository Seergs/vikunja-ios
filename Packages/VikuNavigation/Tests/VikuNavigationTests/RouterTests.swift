import Testing
@testable import VikuNavigation

private enum TestRoute: Hashable {
    case detail(String)
    case settings
}

@MainActor
struct RouterTests {
    @Test
    func `starts with an empty path`() {
        let router = Router<TestRoute>()

        #expect(router.path.isEmpty)
    }

    @Test
    func `push appends to the path`() {
        let router = Router<TestRoute>()

        router.push(.detail("42"))

        #expect(router.path.count == 1)
    }

    @Test
    func `pop removes the last route`() {
        let router = Router<TestRoute>()
        router.push(.detail("42"))
        router.push(.settings)

        router.pop()

        #expect(router.path.count == 1)
    }

    @Test
    func `pop on an empty path is A no op`() {
        let router = Router<TestRoute>()

        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test
    func `pop to root clears the path`() {
        let router = Router<TestRoute>()
        router.push(.detail("1"))
        router.push(.detail("2"))
        router.push(.settings)

        router.popToRoot()

        #expect(router.path.isEmpty)
    }
}
