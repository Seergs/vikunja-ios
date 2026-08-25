import VikunjaCore

enum ProjectMapper {
    static func toDomain(_ dto: ProjectDTO) -> Project {
        Project(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            isArchived: dto.isArchived ?? false,
            isFavorite: dto.isFavorite ?? false,
            // The real API's `parent_project_id` is a non-pointer `int64` on the
            // server, so root-level projects come back as `0`, never absent/null —
            // normalize that to `nil` so `ProjectsListViewModel` can treat "no
            // parent" as a single, unambiguous value.
            parentProjectID: dto.parentProjectId == 0 ? nil : dto.parentProjectId,
            position: dto.position ?? 0,
            hexColor: dto.hexColor ?? ""
        )
    }

    static func toDTO(_ project: Project) -> ProjectDTO {
        ProjectDTO(
            id: project.id,
            title: project.title,
            description: project.description,
            isArchived: project.isArchived,
            isFavorite: project.isFavorite,
            parentProjectId: project.parentProjectID,
            position: project.position,
            hexColor: project.hexColor
        )
    }
}
