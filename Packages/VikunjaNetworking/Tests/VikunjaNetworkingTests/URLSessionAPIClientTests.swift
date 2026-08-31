import Foundation
import Testing
import VikunjaCore
@testable import VikunjaNetworking

// MockURLProtocol uses static state shared across requests, so this suite runs
// serialized to avoid clobbering itself with tests running in parallel.
@Suite(.serialized)
struct URLSessionAPIClientTests {
    @Test
    func decodesSuccessfulResponse() async throws {
        let (session, _) = MockURLProtocol.makeSession(statusCode: 200, body: #"{"version":"0.24.6"}"#)
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)

        let info: ServerInfoDTO = try await client.send(VikunjaEndpoints.info())

        #expect(info.version == "0.24.6")
    }

    @Test
    func mapsUnauthorizedStatusToDomainError() async throws {
        let (session, _) = MockURLProtocol.makeSession(statusCode: 401, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)

        await #expect(throws: VikunjaError.unauthorized) {
            let _: ServerInfoDTO = try await client.send(VikunjaEndpoints.info())
        }
    }

    @Test
    func attachesBearerTokenFromProvider() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: #"{"version":"0.24.6"}"#)
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://vikunja.example.com")!,
            session: session,
            authTokenProvider: { "test-token" }
        )

        let _: ServerInfoDTO = try await client.send(VikunjaEndpoints.info())

        #expect(await capture.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    // `VikunjaTaskRepository.update(_:)`'s safe-update behavior is tested
    // here rather than in its own suite: it's driven by the same
    // `MockURLProtocol` shared static state, and `.serialized` only
    // serializes tests *within* one suite — a second suite touching that
    // state runs concurrently with this one by default and corrupts it.
    @Test
    func updateFetchesTheCurrentTaskFirstThenSendsAMergedBody() async throws {
        let getResponse = #"""
        {
          "id": 1, "title": "Buy coffee", "description": "Whole beans", "done": false,
          "due_date": "2026-08-30T00:00:00Z", "priority": 3, "project_id": 4,
          "percent_done": 0.5, "hex_color": "00ff00", "is_favorite": true,
          "repeat_after": 604800, "repeat_mode": 1, "cover_image_attachment_id": 42
        }
        """#
        // Simulates Vikunja's real behavior: the update response doesn't
        // echo every field back (no percent_done/hex_color/... here) — that
        // asymmetry is exactly why `update(_:)` must merge onto a prior GET
        // rather than trust this response to carry everything.
        let postResponse = #"""
        {
          "id": 1, "title": "Buy coffee", "description": "Whole beans", "done": true,
          "due_date": "2026-08-30T00:00:00Z", "priority": 3, "project_id": 4
        }
        """#
        let (session, capture) = MockURLProtocol.makeSession(responses: [
            (200, getResponse),
            (200, postResponse),
        ])
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaTaskRepository(client: client)

        let updated = try await repository.update(
            VikunjaTask(id: 1, title: "Buy coffee", description: "Whole beans", isDone: true, priority: .high, projectID: 4)
        )

        #expect(updated.isDone == true)

        let requests = await capture.requests
        #expect(requests.count == 2)
        #expect(requests[0].httpMethod == "GET")
        #expect(requests[0].url?.path == "/api/v1/tasks/1")
        #expect(requests[1].httpMethod == "POST")
        #expect(requests[1].url?.path == "/api/v1/tasks/1")

        let sentBody = try #require(requests[1].httpBody)
        let sentJSON = try #require(JSONSerialization.jsonObject(with: sentBody) as? [String: Any])
        #expect(sentJSON["done"] as? Bool == true)
        #expect(sentJSON["percent_done"] as? Double == 0.5)
        #expect(sentJSON["hex_color"] as? String == "00ff00")
        #expect(sentJSON["is_favorite"] as? Bool == true)
        #expect(sentJSON["repeat_after"] as? Int == 604_800)
        #expect(sentJSON["repeat_mode"] as? Int == 1)
        #expect(sentJSON["cover_image_attachment_id"] as? Int == 42)
    }

    // `VikunjaLabelRepository` is tested here rather than in its own suite
    // for the same reason as `VikunjaTaskRepository.update(_:)` above: it
    // shares `MockURLProtocol`'s static state with this suite, and only
    // tests *within* one `.serialized` suite are guaranteed not to run
    // concurrently with each other.

    @Test
    func fetchLabelsDecodesTheLabelList() async throws {
        let (session, _) = MockURLProtocol.makeSession(
            statusCode: 200,
            body: #"[{"id":10,"title":"home","hex_color":"ff00ff"}]"#
        )
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaLabelRepository(client: client)

        let labels = try await repository.fetchLabels()

        #expect(labels == [Label(id: 10, title: "home", hexColor: "ff00ff")])
    }

    @Test
    func createLabelPUTsToTheLabelsEndpoint() async throws {
        let (session, capture) = MockURLProtocol.makeSession(
            statusCode: 200,
            body: #"{"id":11,"title":"work","hex_color":"00ff00"}"#
        )
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaLabelRepository(client: client)

        let created = try await repository.create(Label(id: 0, title: "work", hexColor: "00ff00"))

        #expect(created == Label(id: 11, title: "work", hexColor: "00ff00"))
        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/api/v1/labels")
    }

    @Test
    func deleteLabelDELETEsTheLabelByID() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaLabelRepository(client: client)

        try await repository.delete(id: 11)

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/api/v1/labels/11")
    }

    @Test
    func addLabelPUTsTheLabelIDOntoTheTasksLabelsEndpoint() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaLabelRepository(client: client)

        try await repository.addLabel(10, toTask: 1)

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/api/v1/tasks/1/labels")
        let sentBody = try #require(request.httpBody)
        let sentJSON = try #require(JSONSerialization.jsonObject(with: sentBody) as? [String: Any])
        #expect(sentJSON["label_id"] as? Int == 10)
    }

    @Test
    func removeLabelDELETEsTheLabelFromTheTask() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaLabelRepository(client: client)

        try await repository.removeLabel(10, fromTask: 1)

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/api/v1/tasks/1/labels/10")
    }

    // `VikunjaTaskRelationRepository` is tested here for the same reason as
    // `VikunjaLabelRepository` above.

    @Test
    func addRelationPUTsTheRelationKindAndOtherTaskIDOntoTheTasksRelationsEndpoint() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaTaskRelationRepository(client: client)

        try await repository.addRelation(kind: .subtask, otherTaskID: 2, toTask: 1)

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/api/v1/tasks/1/relations")
        let sentBody = try #require(request.httpBody)
        let sentJSON = try #require(JSONSerialization.jsonObject(with: sentBody) as? [String: Any])
        #expect(sentJSON["relation_kind"] as? String == "subtask")
        #expect(sentJSON["other_task_id"] as? Int == 2)
    }

    @Test
    func removeRelationDELETEsTheRelationByKindAndOtherTaskID() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaTaskRelationRepository(client: client)

        try await repository.removeRelation(kind: .blocked, otherTaskID: 3, fromTask: 1)

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/api/v1/tasks/1/relations/blocked/3")
    }

    @Test
    func fetchCurrentUserGETsTheUserAndReadsTheNestedDefaultProject() async throws {
        let body = #"""
        {"id": 3, "username": "qa-user", "name": "QA User",
         "settings": {"default_project_id": 6, "week_start": 0}}
        """#
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: body)
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaUserRepository(client: client)

        let user = try await repository.fetchCurrentUser()

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/api/v1/user")
        #expect(user.defaultProjectID == 6)
    }

    @Test
    func deleteProjectDELETEsTheProjectByID() async throws {
        let (session, capture) = MockURLProtocol.makeSession(statusCode: 200, body: "")
        let client = URLSessionAPIClient(baseURL: URL(string: "https://vikunja.example.com")!, session: session)
        let repository = VikunjaProjectRepository(client: client)

        try await repository.delete(id: 7)

        let request = try #require(await capture.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/api/v1/projects/7")
    }
}
