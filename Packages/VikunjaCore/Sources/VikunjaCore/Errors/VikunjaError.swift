public enum VikunjaError: Error, Equatable, Sendable {
    case unauthorized
    case notFound
    case invalidInstanceURL
    case server(message: String, statusCode: Int)
    case decoding(String)
    case network(String)
    case unsupportedServerVersion(minimumRequired: String, actual: String)
}
