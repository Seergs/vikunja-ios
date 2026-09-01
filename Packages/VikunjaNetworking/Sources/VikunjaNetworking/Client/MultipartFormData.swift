import Foundation

/// Builds a `multipart/form-data` request body. Kept minimal — Vikunja's only
/// multipart endpoint is the task-attachment upload, which takes one repeated
/// field (`files`).
struct MultipartFormData: Sendable {
    struct Part: Sendable {
        let name: String
        let fileName: String
        let mimeType: String
        let data: Data
    }

    let boundary: String
    private(set) var parts: [Part] = []

    init(boundary: String = "VikunjaBoundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addFile(name: String, fileName: String, mimeType: String, data: Data) {
        parts.append(Part(name: name, fileName: sanitized(fileName), mimeType: mimeType, data: data))
    }

    func encoded() -> Data {
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(part.fileName)\"\r\n")
            body.append("Content-Type: \(part.mimeType)\r\n\r\n")
            body.append(part.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
    }

    /// Strips the characters that would break the `Content-Disposition`
    /// header line: quotes and CR/LF.
    private func sanitized(_ fileName: String) -> String {
        fileName
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
