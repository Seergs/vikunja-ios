import Foundation

/// Reads the `exp` claim out of a JWT's payload segment without validating
/// its signature — good enough to decide "is this worth trying to use
/// before refreshing it," not for anything security-sensitive.
enum JWTExpiryReader {
    static func expiry(of jwt: String) -> Date? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
        payload = payload.replacingOccurrences(of: "-", with: "+")
        payload = payload.replacingOccurrences(of: "_", with: "/")
        while !payload.count.isMultiple(of: 4) {
            payload.append("=")
        }

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double
        else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }
}
