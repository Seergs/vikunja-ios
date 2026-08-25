import VikunjaCore

enum LabelMapper {
    static func toDomain(_ dto: LabelDTO) -> Label {
        Label(id: dto.id, title: dto.title, hexColor: dto.hexColor)
    }

    static func toDTO(_ label: Label) -> LabelDTO {
        LabelDTO(id: label.id, title: label.title, hexColor: label.hexColor)
    }
}
