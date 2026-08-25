import VikunjaCore

enum ProjectMapper {
    static func toDomain(_ dto: ProjectDTO) -> Project {
        Project(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            isArchived: dto.isArchived ?? false,
            isFavorite: dto.isFavorite ?? false,
            parentProjectID: dto.parentProjectId,
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
