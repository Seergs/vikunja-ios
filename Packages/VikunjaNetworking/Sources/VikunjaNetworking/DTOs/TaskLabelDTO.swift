struct TaskLabelDTO: Codable {
    let labelId: Int

    enum CodingKeys: String, CodingKey {
        case labelId = "label_id"
    }
}
