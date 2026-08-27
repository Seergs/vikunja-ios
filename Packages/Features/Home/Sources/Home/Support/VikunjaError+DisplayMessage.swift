import VikunjaCore

/// User-facing copy for the errors a load can surface, shared by every load
/// state in this feature so the wording stays consistent across screens.
extension VikunjaError {
    var displayMessage: String {
        switch self {
        case .invalidInstanceURL:
            return "That doesn't look like a valid instance address."
        case .network:
            return "Couldn't reach that server. Check the address and your connection."
        case .notFound, .decoding:
            return "That address didn't respond like a Vikunja instance."
        case .unauthorized:
            return "That server rejected the request."
        case let .server(_, statusCode):
            return "The server responded with an error (\(statusCode))."
        case let .unsupportedServerVersion(minimumRequired, _):
            return "This app needs Vikunja \(minimumRequired) or newer."
        }
    }
}
