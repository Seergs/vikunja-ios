struct LoginRequestDTO: Encodable {
    let username: String
    let password: String
}

struct AuthTokenDTO: Decodable {
    let token: String
}
