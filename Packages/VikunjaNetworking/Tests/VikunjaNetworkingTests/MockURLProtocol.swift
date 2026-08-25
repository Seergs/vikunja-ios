import Foundation

actor RequestCapture {
    private(set) var requests: [URLRequest] = []

    var lastRequest: URLRequest? { requests.last }

    func record(_ request: URLRequest) {
        requests.append(request)
    }
}

final class MockURLProtocol: URLProtocol {
    private struct Response {
        let statusCode: Int
        let body: Data
    }

    nonisolated(unsafe) private static var responses: [Response] = []
    nonisolated(unsafe) static var capture: RequestCapture?

    /// Single canned response reused for every request the session makes.
    static func makeSession(statusCode: Int, body: String) -> (URLSession, RequestCapture) {
        makeSession(responses: [(statusCode, body)])
    }

    /// One response per request, consumed in order — for a call that issues
    /// more than one request (e.g. `VikunjaTaskRepository.update(_:)`'s
    /// GET-then-POST safe-update) and each leg needs its own reply. The last
    /// queued response repeats if more requests arrive than were queued.
    static func makeSession(responses: [(statusCode: Int, body: String)]) -> (URLSession, RequestCapture) {
        let capture = RequestCapture()
        Self.responses = responses.map { Response(statusCode: $0.statusCode, body: Data($0.body.utf8)) }
        Self.capture = capture

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return (URLSession(configuration: configuration), capture)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // `URLSession` moves a POST/PUT body into `httpBodyStream` when
        // dispatching through a custom `URLProtocol`, leaving `httpBody`
        // nil — read the stream now (it can only be consumed once) so
        // callers inspecting the captured request's body don't see nil.
        var request = self.request
        if request.httpBody == nil, let bodyData = Self.readBody(from: request) {
            request.httpBody = bodyData
        }
        // A fresh `let` snapshot to hand to the `Task` below — capturing
        // the `var` itself trips Swift 6's strict-concurrency "sending"
        // check, since this function keeps using `request` afterward.
        let capturedRequest = request
        let capture = Self.capture
        Task {
            await capture?.record(capturedRequest)
        }

        let response: Response
        if Self.responses.count > 1 {
            response = Self.responses.removeFirst()
        } else if let only = Self.responses.first {
            response = only
        } else {
            response = Response(statusCode: 200, body: Data())
        }

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(from request: URLRequest) -> Data? {
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
