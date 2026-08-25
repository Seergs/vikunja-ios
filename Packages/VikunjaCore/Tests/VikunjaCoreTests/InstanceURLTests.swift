import Testing
@testable import VikunjaCore

struct InstanceURLTests {
    @Test
    func acceptsABareDomainAndDefaultsToHTTPS() throws {
        let url = try InstanceURL.normalize("tasks.example.com")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func acceptsAFullHTTPSURL() throws {
        let url = try InstanceURL.normalize("https://tasks.example.com")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func acceptsHTTPForLocalInstances() throws {
        let url = try InstanceURL.normalize("http://localhost:3456")

        #expect(url.absoluteString == "http://localhost:3456")
    }

    @Test
    func trimsSurroundingWhitespace() throws {
        let url = try InstanceURL.normalize("  tasks.example.com  ")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func stripsAPastedPathQueryAndTrailingSlash() throws {
        let url = try InstanceURL.normalize("https://tasks.example.com/login?next=/tasks")

        #expect(url.absoluteString == "https://tasks.example.com")
    }

    @Test
    func rejectsAnEmptyString() {
        #expect(throws: VikunjaError.invalidInstanceURL) {
            try InstanceURL.normalize("   ")
        }
    }

    @Test
    func rejectsAnUnsupportedScheme() {
        #expect(throws: VikunjaError.invalidInstanceURL) {
            try InstanceURL.normalize("ftp://tasks.example.com")
        }
    }

    @Test
    func rejectsGarbageInput() {
        #expect(throws: VikunjaError.invalidInstanceURL) {
            try InstanceURL.normalize("not a url")
        }
    }
}
