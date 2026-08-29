import Foundation

enum ScreenLoadState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failure(String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
}
