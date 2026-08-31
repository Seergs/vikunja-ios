import Testing
@testable import VikunjaCore

struct InstanceURLTests {
    @Test
    func `accepts A bare domain and defaults to HTTPS`() throws {
        let url = try InstanceURL.normalize("tasks.example.com")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func `accepts A full HTTPSURL`() throws {
        let url = try InstanceURL.normalize("https://tasks.example.com")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func `accepts HTTP for local instances`() throws {
        let url = try InstanceURL.normalize("http://localhost:3456")

        #expect(url.absoluteString == "http://localhost:3456")
    }

    @Test
    func `trims surrounding whitespace`() throws {
        let url = try InstanceURL.normalize("  tasks.example.com  ")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func `strips A pasted path query and trailing slash`() throws {
        let url = try InstanceURL.normalize("https://tasks.example.com/login?next=/tasks")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func `rejects an empty string`() {
        #expect(throws: VikunjaError.invalidInstanceURL) {
            try InstanceURL.normalize("   ")
        }
    }

    @Test
    func `rejects an unsupported scheme`() {
        #expect(throws: VikunjaError.invalidInstanceURL) {
            try InstanceURL.normalize("ftp://tasks.example.com")
        }
    }

    @Test
    func `rejects garbage input`() {
        #expect(throws: VikunjaError.invalidInstanceURL) {
            try InstanceURL.normalize("not a url")
        }
    }
}
