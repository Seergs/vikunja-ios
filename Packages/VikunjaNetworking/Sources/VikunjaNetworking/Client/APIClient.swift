public protocol APIClient: Sendable {
    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response
    func send(_ endpoint: Endpoint) async throws
}
