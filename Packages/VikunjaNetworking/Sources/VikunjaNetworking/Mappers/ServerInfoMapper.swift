import VikunjaCore

enum ServerInfoMapper {
    static func toDomain(_ dto: ServerInfoDTO) -> VikunjaServerInfo {
        VikunjaServerInfo(
            version: dto.version,
            caldavEnabled: dto.caldavEnabled ?? false,
            totpEnabled: dto.totpEnabled ?? false,
            registrationEnabled: dto.registrationEnabled ?? false,
            maxFileSizeBytes: MaxFileSizeParser.bytes(from: dto.maxFileSize),
            localAuthEnabled: dto.auth?.local?.enabled ?? true,
        )
    }
}
