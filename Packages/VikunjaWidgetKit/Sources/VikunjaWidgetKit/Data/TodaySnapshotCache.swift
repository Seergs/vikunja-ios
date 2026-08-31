import Foundation

/// Reads/writes the last successful Today snapshot as JSON in a directory
/// shared between the app and the widget (the App Group container). Every
/// operation is best-effort: a missing file, an unreadable container, or a
/// decode failure just yields `nil` rather than throwing, so the widget can
/// always render *something*.
public struct TodaySnapshotCache: Sendable {
    private let fileURL: URL?

    /// - Parameter directory: where the snapshot file lives. `nil` (e.g. the
    ///   App Group container is unavailable) turns every call into a no-op.
    public init(directory: URL?) {
        self.fileURL = directory?.appendingPathComponent("today-widget-snapshot.json")
    }

    public init(appGroupIdentifier: String) {
        self.init(
            directory: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier,
            ),
        )
    }

    public func read() -> TodayWidgetContent? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(TodayWidgetContent.self, from: data)
    }

    public func write(_ content: TodayWidgetContent) {
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
