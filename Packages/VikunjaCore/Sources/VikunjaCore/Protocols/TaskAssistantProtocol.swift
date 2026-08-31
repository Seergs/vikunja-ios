/// An on-device text assistant a Feature can lean on for lightweight,
/// privacy-preserving help with a task — reviewing it, suggesting a clearer
/// title, spotting missing detail. The concrete implementation lives in the
/// composition root (it needs Apple's `FoundationModels`, a concrete
/// dependency Features shouldn't see — the same rule networking follows), and
/// callers check `availability` before offering the affordance: on-device
/// generation only works on an Apple Intelligence-capable device with the
/// model downloaded.
public protocol TaskAssistantProtocol: Sendable {
    /// Whether on-device generation is usable right now, and — when it isn't —
    /// a short human-readable reason a caller can show the user.
    var availability: TaskAssistantAvailability { get }

    /// A short, plain-text critique of one task: whether it reads as specific
    /// and actionable, what important detail looks missing, and a crisper
    /// title if the current one is vague. A few sentences, no markup.
    func reviewTask(title: String, description: String) async throws -> String
}

/// The result of checking whether the on-device assistant can run — mirrors
/// `FoundationModels`' own `SystemLanguageModel.Availability`, but kept in
/// `VikunjaCore` so Features can branch on it without importing that SDK.
public enum TaskAssistantAvailability: Sendable, Equatable {
    case available
    /// Not usable here — `reason` is a short sentence fit to show the user
    /// (e.g. "This device doesn't support Apple Intelligence.").
    case unavailable(reason: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// The reason string when `.unavailable`, `nil` when `.available`.
    public var unavailableReason: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

/// Raised by a `TaskAssistantProtocol` implementation when a generation call
/// fails — `message` is fit to show the user.
public enum TaskAssistantError: Error, Sendable, Equatable {
    case unavailable
    case generationFailed(message: String)

    public var message: String {
        switch self {
        case .unavailable:
            return "On-device AI isn't available on this device."
        case .generationFailed(let message):
            return message
        }
    }
}
