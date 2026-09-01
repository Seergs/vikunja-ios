import Foundation
import Testing
@testable import VikunjaNetworking

struct MultipartFormDataTests {
    @Test
    func `encodes A single file part with the exact expected layout`() throws {
        var form = MultipartFormData(boundary: "TESTBOUNDARY")
        form.addFile(name: "files", fileName: "notes.txt", mimeType: "text/plain", data: Data("hello".utf8))

        let body = try #require(String(data: form.encoded(), encoding: .utf8))

        #expect(body == """
        --TESTBOUNDARY\r
        Content-Disposition: form-data; name="files"; filename="notes.txt"\r
        Content-Type: text/plain\r
        \r
        hello\r
        --TESTBOUNDARY--\r

        """)
    }

    @Test
    func `content type carries the boundary`() {
        let form = MultipartFormData(boundary: "abc123")
        #expect(form.contentType == "multipart/form-data; boundary=abc123")
    }

    @Test
    func `strips quotes and newlines from the file name`() throws {
        var form = MultipartFormData(boundary: "B")
        form.addFile(name: "files", fileName: "a\"b\nc.txt", mimeType: "text/plain", data: Data())

        let body = try #require(String(data: form.encoded(), encoding: .utf8))

        #expect(body.contains(#"filename="a'bc.txt""#))
    }

    @Test
    func `keeps binary payload bytes intact`() {
        let payload = Data([0x00, 0xFF, 0x10, 0x80])
        var form = MultipartFormData(boundary: "B")
        form.addFile(name: "files", fileName: "blob.bin", mimeType: "application/octet-stream", data: payload)

        let encoded = form.encoded()

        #expect(encoded.range(of: payload) != nil)
    }
}
