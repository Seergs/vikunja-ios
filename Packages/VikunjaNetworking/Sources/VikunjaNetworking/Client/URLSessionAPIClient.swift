import Foundation
import os
import VikunjaCore

private let apiLogger = Logger(subsystem: "dev.sergiosuarez.vikunja", category: "networking")

/// Concrete `APIClient` implementation on top of `URLSession`. This is the only piece
/// of the project that knows Vikunja speaks HTTP/JSON — `baseURL` and the token are
/// resolved via closures so this client stays decoupled from any particular account
/// or instance.
public actor URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let authTokenProvider: @Sendable () async -> String?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        authTokenProvider: @escaping @Sendable () async -> String? = { nil },
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func send<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        let data = try await sendRaw(endpoint)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw VikunjaError.decoding(String(describing: error))
        }
    }

    public func send(_ endpoint: Endpoint) async throws {
        _ = try await sendRaw(endpoint)
    }

    public func data(_ endpoint: Endpoint) async throws -> Data {
        try await sendRaw(endpoint)
    }

    private func sendRaw(_ endpoint: Endpoint) async throws -> Data {
        guard let url = makeURL(for: endpoint) else {
            throw VikunjaError.invalidInstanceURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        if endpoint.body != nil {
            request.setValue(endpoint.contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = await authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VikunjaError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VikunjaError.network("Received a non-HTTP response from the server")
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return data
        case 401:
            Self.logResponseBody(data, statusCode: 401, endpoint: endpoint)
            throw VikunjaError.unauthorized
        case 404:
            throw VikunjaError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.logResponseBody(data, statusCode: httpResponse.statusCode, endpoint: endpoint)
            throw VikunjaError.server(message: message, statusCode: httpResponse.statusCode)
        }
    }

    /// Surfaces the server's raw error body in the Xcode console / Console.app
    /// (filter by subsystem `dev.sergiosuarez.vikunja`) — `VikunjaError` itself
    /// deliberately shows the user a generic, friendly message instead of the
    /// raw response, so this is the only place that body is visible.
    private static func logResponseBody(_ data: Data, statusCode: Int, endpoint: Endpoint) {
        let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body, \(data.count) bytes>"
        apiLogger.error("\(endpoint.method.rawValue, privacy: .public) \(endpoint.path, privacy: .public) → \(statusCode, privacy: .public): \(body, privacy: .public)")
    }

    private func makeURL(for endpoint: Endpoint) -> URL? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false,
        )
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        return components?.url
    }
}
