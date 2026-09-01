import Foundation

/// Turns Vikunja's `/info` `max_file_size` string into a byte count.
///
/// Vikunja stores this as a free-form config string and echoes it back
/// verbatim, so it can arrive as `"20MB"`, `"20 MB"`, `"20mb"`, `"1GB"`,
/// `"500KB"`, a binary unit (`"20MiB"`), or a plain byte count (`"20971520"`).
/// Anything unparseable yields `nil` — callers fall back to no client-side
/// size check.
enum MaxFileSizeParser {
    static func bytes(from string: String?) -> Int? {
        guard let raw = string?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }

        let scanner = Scanner(string: raw)
        scanner.charactersToBeSkipped = .whitespaces
        guard let value = scanner.scanDouble() else { return nil }

        let unit = raw[scanner.currentIndex...]
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        let multiplier: Double
        switch unit {
        case "", "b": multiplier = 1
        case "k", "kb", "kib": multiplier = 1024
        case "m", "mb", "mib": multiplier = 1024 * 1024
        case "g", "gb", "gib": multiplier = 1024 * 1024 * 1024
        case "t", "tb", "tib": multiplier = 1024 * 1024 * 1024 * 1024
        default: return nil
        }

        let bytes = value * multiplier
        guard bytes.isFinite, bytes >= 0, bytes < Double(Int.max) else { return nil }
        return Int(bytes)
    }
}
