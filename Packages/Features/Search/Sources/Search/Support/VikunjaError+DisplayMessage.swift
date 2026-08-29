import VikunjaCore

extension VikunjaError {
    var displayMessage: String {
        switch self {
        case .network(let message):
            return message.isEmpty ? "Network error. Check your connection." : message
        case .decoding(let message):
            return message.isEmpty ? "Could not process server response." : message
        case .unauthorized:
            return "Authentication failed. Please sign in again."
        case .notFound:
            return "Task not found."
        case .invalidInstanceURL:
            return "Invalid instance URL."
        case .server(let message, let statusCode):
            return message.isEmpty ? "Server error (\(statusCode))." : message
        case .unsupportedServerVersion(let minimumRequired, let actual):
            return "Server version \(actual) is not supported. Minimum required: \(minimumRequired)."
        }
    }
}
