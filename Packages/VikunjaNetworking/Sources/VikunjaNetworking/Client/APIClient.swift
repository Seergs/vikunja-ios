import Foundation

public protocol APIClient: Sendable {
    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response
    func send(_ endpoint: Endpoint) async throws
    /// Returns the response body untouched — for endpoints that serve raw
    /// bytes rather than JSON (an attachment download).
    func data(_ endpoint: Endpoint) async throws -> Data
    /// Like `send(_:)`, but also returns the raw HTTP response so a caller
    /// can read response headers (`Set-Cookie`) the decoded JSON body
    /// doesn't carry. Used only by the password-session refresh flow.
    func sendWithResponse<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> (Response, HTTPURLResponse)
}
