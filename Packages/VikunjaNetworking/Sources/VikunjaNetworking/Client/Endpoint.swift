import Foundation

public struct Endpoint: Sendable {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    public let path: String
    public let method: Method
    public let queryItems: [URLQueryItem]
    public let body: Data?
    /// `Content-Type` header for `body`. `nil` lets the client default to
    /// `application/json` (the shape `.encoding(...)` produces); a multipart
    /// upload sets it explicitly to carry its boundary.
    public let contentType: String?

    public init(
        path: String,
        method: Method = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = nil,
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.contentType = contentType
    }

    static func encoding(
        path: String,
        method: Method,
        queryItems: [URLQueryItem] = [],
        body: some Encodable,
    ) throws -> Endpoint {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try Endpoint(path: path, method: method, queryItems: queryItems, body: encoder.encode(body))
    }

    /// A `multipart/form-data` request built from `form` — used for file
    /// uploads, the one case Vikunja doesn't take a JSON body.
    static func multipart(
        path: String,
        method: Method,
        form: MultipartFormData,
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: method,
            body: form.encoded(),
            contentType: form.contentType,
        )
    }
}
