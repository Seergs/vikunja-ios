import VikunjaCore

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
        try .encoding(path: "/api/v1/projects/\(projectID)/tasks", method: .put, body: dto)
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

    static func labels() -> Endpoint {
        Endpoint(path: "/api/v1/labels")
    }

    static func createLabel(dto: LabelDTO) throws -> Endpoint {
        try .encoding(path: "/api/v1/labels", method: .put, body: dto)
    }

    static func updateLabel(id: Int, dto: LabelDTO) throws -> Endpoint {
        try .encoding(path: "/api/v1/labels/\(id)", method: .post, body: dto)
    }

    static func deleteLabel(id: Int) -> Endpoint {
        Endpoint(path: "/api/v1/labels/\(id)", method: .delete)
    }

    static func addLabelToTask(taskID: Int, labelID: Int) throws -> Endpoint {
        try .encoding(
            path: "/api/v1/tasks/\(taskID)/labels",
            method: .put,
            body: TaskLabelDTO(labelId: labelID)
        )
    }

    static func removeLabelFromTask(taskID: Int, labelID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/tasks/\(taskID)/labels/\(labelID)", method: .delete)
    }

    static func createTaskRelation(taskID: Int, kind: RelationKind, otherTaskID: Int) throws -> Endpoint {
        try .encoding(
            path: "/api/v1/tasks/\(taskID)/relations",
            method: .put,
            body: CreateTaskRelationDTO(relationKind: kind.rawValue, otherTaskId: otherTaskID)
        )
    }

    static func deleteTaskRelation(taskID: Int, kind: RelationKind, otherTaskID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/tasks/\(taskID)/relations/\(kind.rawValue)/\(otherTaskID)", method: .delete)
    }
}
