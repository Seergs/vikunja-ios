#if canImport(WidgetKit)
import SwiftUI
import VikunjaCore
import VikunjaDesignSystem
import WidgetKit

/// Root view for every `TodayWidget` family. Branches on the timeline state,
/// then on `widgetFamily` for the content layout.
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    /// System content margins are disabled on the configuration; this is the
    /// inset every family gets instead, kept generous so text never reaches
    /// the widget edge.
    private var contentInset: EdgeInsets {
        family == .systemSmall
            ? EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            : EdgeInsets(top: 15, leading: 18, bottom: 15, trailing: 18)
    }

    var body: some View {
        content
            .padding(contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(VikunjaColor.Surface.page, for: .widget)
            .widgetURL(URL(string: "\(VikunjaWidgetConfig.urlScheme)://today"))
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .notConnected:
            TodayWidgetMessage(
                systemImage: "link.circle",
                title: "Not connected",
                message: "Open Vikunja to add your instance."
            )
        case .needsAuth:
            TodayWidgetMessage(
                systemImage: "lock.circle",
                title: "Sign in again",
                message: "Your token was rejected. Re-add the connection in Settings."
            )
        case .unavailable:
            TodayWidgetMessage(
                systemImage: "wifi.slash",
                title: "Couldn't refresh",
                message: "No connection and nothing saved yet."
            )
        case let .content(content):
            loadedContent(content)
        }
    }

    @ViewBuilder
    private func loadedContent(_ content: TodayWidgetContent) -> some View {
        switch family {
        case .systemSmall:
            TodaySmallView(content: content)
        case .systemMedium:
            TodayListView(content: content, rowLimit: 3)
        default:
            TodayListView(content: content, rowLimit: VikunjaWidgetConfig.taskLimit)
        }
    }
}

// MARK: - Small

private struct TodaySmallView: View {
    let content: TodayWidgetContent

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
            TodayWidgetHeader(content: content)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: VikunjaSpacing.xxs) {
                Text("\(content.pendingCount)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(content.pendingCount == 1 ? "task" : "tasks")
                    .font(VikunjaFont.caption)
                    .foregroundStyle(VikunjaColor.textSecondary)
            }

            Text(pendingBreakdown)
                .font(VikunjaFont.caption2)
                .foregroundStyle(VikunjaColor.textSecondary)
        }
    }

    private var pendingBreakdown: String {
        if content.overdueCount > 0 {
            return "\(content.overdueCount) overdue · \(content.todayCount) today"
        }
        return "\(content.todayCount) today · \(content.upcomingCount) upcoming"
    }
}

// MARK: - Medium / Large

private struct TodayListView: View {
    let content: TodayWidgetContent
    let rowLimit: Int

    private var rows: [TodayWidgetTask] {
        Array(content.tasks.prefix(rowLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.xs) {
            TodayWidgetHeader(content: content)

            if rows.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing due. Enjoy it.")
                    .font(VikunjaFont.caption)
                    .foregroundStyle(VikunjaColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: VikunjaSpacing.xs) {
                    ForEach(rows) { task in
                        TodayWidgetRow(task: task)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct TodayWidgetRow: View {
    let task: TodayWidgetTask

    private var projectColor: Color {
        Color(vikunjaHex: task.projectColorHex) ?? VikunjaColor.brandPrimary
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.xs + VikunjaSpacing.xxs) {
            toggle

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(VikunjaFont.caption)
                    .fontWeight(.medium)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? VikunjaColor.textTertiary : Color.primary)
                    .lineLimit(1)

                HStack(spacing: VikunjaSpacing.xs) {
                    if !task.projectName.isEmpty {
                        Circle().fill(projectColor).frame(width: 4, height: 4)
                        Text(task.projectName)
                            .foregroundStyle(VikunjaColor.textSecondary)
                    }
                    if let due = dueLabel {
                        Text("· \(due)")
                            .foregroundStyle(task.bucket == .overdue ? VikunjaColor.Semantic.dangerText : VikunjaColor.textSecondary)
                    }
                }
                .font(VikunjaFont.caption2)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var toggle: some View {
        let circle = Circle()
            .strokeBorder(task.isDone ? Color.clear : projectColor, lineWidth: 1.5)
            .background(Circle().fill(task.isDone ? projectColor : Color.clear))
            .frame(width: 14, height: 14)
            .overlay {
                if task.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

        #if os(iOS)
        Button(intent: ToggleTaskDoneIntent(taskID: task.id)) { circle }
            .buttonStyle(.plain)
        #else
        circle
        #endif
    }

    private var dueLabel: String? {
        guard let dueDate = task.dueDate else { return nil }
        switch task.bucket {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .upcoming:
            return dueDate.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Shared pieces

private struct TodayWidgetHeader: View {
    let content: TodayWidgetContent

    var body: some View {
        HStack(spacing: VikunjaSpacing.xs) {
            Text("Today")
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .kerning(0.4)
                .foregroundStyle(VikunjaColor.textSecondary)
            Spacer(minLength: 0)
            if content.isStale {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VikunjaColor.textTertiary)
                    .accessibilityLabel("Showing saved data")
            }
        }
    }
}

private struct TodayWidgetMessage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: VikunjaSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(VikunjaColor.textTertiary)
            Text(title)
                .font(VikunjaFont.caption)
                .fontWeight(.semibold)
            Text(message)
                .font(VikunjaFont.caption2)
                .foregroundStyle(VikunjaColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
