import SwiftUI
import VikunjaCore
import VikunjaNavigation

public struct SearchRootView: View {
    @State private var router = Router<SearchRoute>()
    @State private var viewModel: SearchViewModel

    private let onTaskSelected: ((VikunjaTask, Project) -> AnyView)?

    public init(
        viewModel: SearchViewModel,
        onTaskSelected: ((VikunjaTask, Project) -> AnyView)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onTaskSelected = onTaskSelected
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            SearchView(viewModel: viewModel, onTaskSelected: onTaskSelected)
                .searchable(
                    text: $viewModel.query,
                    placement: .automatic,
                    prompt: "Search tasks"
                )
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.queryChanged()
                }
        }
    }
}
