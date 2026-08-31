import SwiftUI
import VikunjaCore
import VikunjaDesignSystem
import VikunjaNavigation

/// Lists every label on the active account, with a swatch + title per row.
/// Tap a row to rename/recolor it, the toolbar "+" to create one, swipe to
/// delete (behind a confirmation). Both create and edit happen in
/// `LabelEditorSheet`, presented as a `.sheet` rather than a pushed route.
struct ManageLabelsView: View {
    @State private var viewModel: ManageLabelsViewModel
    @State private var editorMode: LabelEditorMode?
    @State private var pendingDeletion: VikunjaCore.Label?

    /// Same rationale as `ConnectionsListView`: takes a factory and builds
    /// the view model inside `@State`'s initializer so SwiftUI keeps one
    /// instance (and its loaded `labels`) across any re-invocation of
    /// `SettingsRootView`'s `navigationDestination` content closure.
    init(makeViewModel: @escaping () -> ManageLabelsViewModel) {
        _viewModel = State(initialValue: makeViewModel())
    }

    var body: some View {
        content
            .background(VikunjaColor.Surface.page)
            .navigationTitle("Manage Labels")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorMode = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Label")
                }
            }
            .sheet(item: $editorMode) { mode in
                LabelEditorSheet(mode: mode) { title, hexColor in
                    switch mode {
                    case .create:
                        await viewModel.createLabel(title: title, hexColor: hexColor)
                    case let .edit(label):
                        await viewModel.updateLabel(label, title: title, hexColor: hexColor)
                    }
                }
            }
            .confirmationDialog(
                "Delete this label?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: {
                    if !$0 {
                        pendingDeletion = nil
                    }
                }),
                titleVisibility: .visible,
                presenting: pendingDeletion,
            ) { (label: VikunjaCore.Label) in
                Button("Delete \"\(label.title)\"", role: .destructive) {
                    Task { await viewModel.deleteLabel(label) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { (_: VikunjaCore.Label) in
                Text("It will be removed from every task it's attached to.")
            }
            // `.onAppear` rather than `.task`: this view's identity survives a
            // sheet presentation and dismissal, so a one-shot `.task` would
            // never refire.
            .onAppear { Task { await viewModel.load() } }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, VikunjaSpacing.xxl)
        case let .failure(message):
            LabelsStatusView(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load labels",
                message: message,
            ) {
                Task { await viewModel.load() }
            }
            .padding(.top, VikunjaSpacing.xxl)
        case .loaded:
            if viewModel.labels.isEmpty {
                LabelsStatusView(
                    systemImage: "tag",
                    title: "No labels yet",
                    message: "Create a label to organize tasks across every project.",
                )
                .padding(.top, VikunjaSpacing.xxl)
            } else {
                List {
                    ForEach(viewModel.labels) { label in
                        Button {
                            editorMode = .edit(label)
                        } label: {
                            LabelRow(label: label)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            // `role: .destructive` alone renders blue here, not
                            // red: the tab bar's `.tint(VikunjaColor.brandPrimary)`
                            // leaks into the swipe action, so tint it explicitly.
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = label
                            }
                            .tint(VikunjaColor.Semantic.danger)
                        }
                    }
                }
                .labelsListStyle()
            }
        }
    }
}

private struct LabelRow: View {
    let label: VikunjaCore.Label

    private var color: Color {
        Color(vikunjaHex: label.hexColor) ?? VikunjaColor.textSecondary
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label.title)
                .font(VikunjaFont.body)
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VikunjaColor.textTertiary)
        }
        .padding(.vertical, VikunjaSpacing.xxs)
        .contentShape(Rectangle())
    }
}

/// Shared empty/error state layout for the labels screen — mirrors
/// `ConnectionsListView`'s own status view.
private struct LabelsStatusView: View {
    let systemImage: String
    let title: String
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: VikunjaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(VikunjaColor.textTertiary)

            Text(title)
                .font(VikunjaFont.headline)

            Text(message)
                .font(VikunjaFont.subheadline)
                .foregroundStyle(VikunjaColor.textSecondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.bordered)
                    .padding(.top, VikunjaSpacing.xs)
            }
        }
        .padding(VikunjaSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension View {
    @ViewBuilder
    func labelsListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}
