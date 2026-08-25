import Testing
@testable import VikunjaNavigation

private enum TestRoute: Hashable {
    case detail(String)
    case settings
}

@MainActor
struct RouterTests {
    @Test
    func startsWithAnEmptyPath() {
        let router = Router<TestRoute>()

        #expect(router.path.isEmpty)
    }

    @Test
    func pushAppendsToThePath() {
        let router = Router<TestRoute>()

        router.push(.detail("42"))

        #expect(router.path.count == 1)
    }

    @Test
    func popRemovesTheLastRoute() {
        let router = Router<TestRoute>()
        router.push(.detail("42"))
        router.push(.settings)

        router.pop()

        #expect(router.path.count == 1)
    }

    @Test
    func popOnAnEmptyPathIsANoOp() {
        let router = Router<TestRoute>()

        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test
    func popToRootClearsThePath() {
        let router = Router<TestRoute>()
        router.push(.detail("1"))
        router.push(.detail("2"))
        router.push(.settings)

        router.popToRoot()

        #expect(router.path.isEmpty)
    }
}
