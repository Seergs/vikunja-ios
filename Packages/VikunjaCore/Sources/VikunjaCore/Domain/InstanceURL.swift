import Foundation

/// Normalizes a user-entered instance address — a bare domain
/// (`tasks.example.com`) or a full URL (`https://tasks.example.com`) — into the
/// scheme+host `URL` the networking layer expects as `baseURL`: no path, no
/// trailing slash, no query/fragment, so `Endpoint.path` (which already starts
/// with `/api/v1/...`) appends onto it cleanly.
public enum InstanceURL {
    public static func normalize(_ rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VikunjaError.invalidInstanceURL }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"

        guard var components = URLComponents(string: candidate) else {
            throw VikunjaError.invalidInstanceURL
        }
        guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw VikunjaError.invalidInstanceURL
        }
        guard let host = components.host, !host.isEmpty else {
            throw VikunjaError.invalidInstanceURL
        }

        components.path = ""
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil

        guard let url = components.url else { throw VikunjaError.invalidInstanceURL }
        return url
    }
}
