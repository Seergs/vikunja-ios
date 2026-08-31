struct LabelDTO: Codable {
    let id: Int
    let title: String
    let hexColor: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case hexColor = "hex_color"
    }
}
