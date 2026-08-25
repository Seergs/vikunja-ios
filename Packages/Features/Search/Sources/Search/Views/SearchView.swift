import SwiftUI

/// Placeholder landing screen for the Search tab. Real content (query field,
/// results across tasks/projects) isn't built yet.
struct SearchView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Search")
                .font(.title2)
        }
        .padding()
        .navigationTitle("Search")
    }
}
