enum VikunjaEndpoints {
    static func info() -> Endpoint {
        Endpoint(path: "/api/v1/info")
    }

    static func login(username: String, password: String) throws -> Endpoint {
        try .encoding(
            path: "/api/v1/login",
            method: .post,
            body: LoginRequestDTO(username: username, password: password)
        )
    }

    static func tasks(projectID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/projects/\(projectID)/tasks")
    }

    static func task(id: Int) -> Endpoint {
        Endpoint(path: "/api/v1/tasks/\(id)")
    }

    static func createTask(projectID: Int, dto: TaskDTO) throws -> Endpoint {
        try .encoding(path: "/api/v1/projects/\(projectID)/tasks", method: .post, body: dto)
    }

    static func updateTask(id: Int, dto: TaskDTO) throws -> Endpoint {
        try .encoding(path: "/api/v1/tasks/\(id)", method: .post, body: dto)
    }

    static func deleteTask(id: Int) -> Endpoint {
        Endpoint(path: "/api/v1/tasks/\(id)", method: .delete)
    }

    static func projects() -> Endpoint {
        Endpoint(path: "/api/v1/projects")
    }

    static func project(id: Int) -> Endpoint {
        Endpoint(path: "/api/v1/projects/\(id)")
    }

    static func createProject(dto: ProjectDTO) throws -> Endpoint {
        try .encoding(path: "/api/v1/projects", method: .put, body: dto)
    }

    static func updateProject(id: Int, dto: ProjectDTO) throws -> Endpoint {
        try .encoding(path: "/api/v1/projects/\(id)", method: .post, body: dto)
    }

    static func deleteProject(id: Int) -> Endpoint {
        Endpoint(path: "/api/v1/projects/\(id)", method: .delete)
    }
}
