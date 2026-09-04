import Foundation

/// Reads/writes the last successful calendar-widget snapshot as JSON in the App
/// Group container shared between the app and the widget. Best-effort in exactly
/// the same way as `TodaySnapshotCache`: any failure yields `nil`/no-op so the
/// widget can always render something.
public struct CalendarSnapshotCache: Sendable {
    private let fileURL: URL?

    /// - Parameter directory: where the snapshot file lives. `nil` (e.g. the
    ///   App Group container is unavailable) turns every call into a no-op.
    public init(directory: URL?) {
        self.fileURL = directory?.appendingPathComponent("calendar-widget-snapshot.json")
    }

    public init(appGroupIdentifier: String) {
        self.init(
            directory: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier,
            ),
        )
    }

    public func read() -> CalendarWidgetContent? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(CalendarWidgetContent.self, from: data)
    }

    public func write(_ content: CalendarWidgetContent) {
        guard let fileURL, let data = try? Self.encoder.encode(content) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
