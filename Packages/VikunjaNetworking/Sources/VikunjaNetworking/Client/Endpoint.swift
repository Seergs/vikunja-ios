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

    public init(
        path: String,
        method: Method = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
    }

    static func encoding<Body: Encodable>(
        path: String,
        method: Method,
        queryItems: [URLQueryItem] = [],
        body: Body
    ) throws -> Endpoint {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return Endpoint(path: path, method: method, queryItems: queryItems, body: try encoder.encode(body))
    }
}
