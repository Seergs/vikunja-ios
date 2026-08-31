import Foundation
import VikunjaCore

#if canImport(FoundationModels)
import FoundationModels
#endif

/// `TaskAssistantProtocol` backed by Apple's on-device model (Apple
/// Intelligence / `FoundationModels`). Everything runs on device — nothing
/// about a task leaves the phone.
///
/// Lives in the app target rather than a `Features/*` package for two reasons:
/// `FoundationModels` is a concrete dependency Features aren't allowed to
/// import (the same rule `VikunjaNetworking` follows), and it needs the iOS 26
/// SDK, above the packages' iOS 17 floor.
///
/// This is a proof of concept: one prompt, one call, plain-text answer.
struct FoundationModelsTaskAssistant: TaskAssistantProtocol {
    var availability: TaskAssistantAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(reason: "This device doesn't support Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(reason: "Turn on Apple Intelligence in Settings to use this.")
            case .unavailable(.modelNotReady):
                return .unavailable(reason: "The on-device model is still downloading. Try again later.")
            case .unavailable:
                return .unavailable(reason: "On-device AI isn't available right now.")
            @unknown default:
                return .unavailable(reason: "On-device AI isn't available right now.")
            }
        }
        return .unavailable(reason: "On-device AI needs iOS 26 or later.")
        #else
        return .unavailable(reason: "On-device AI isn't available on this build.")
        #endif
    }

    func reviewTask(title: String, description: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let session = LanguageModelSession(instructions: Self.instructions)
            let prompt = """
            Title: \(title)
            Description: \(description.isEmpty ? "(none)" : description)
            """
            do {
                return try await session.respond(to: prompt).content
            } catch let error as LanguageModelSession.GenerationError {
                throw TaskAssistantError.generationFailed(message: Self.message(for: error))
            } catch {
                throw TaskAssistantError.generationFailed(message: error.localizedDescription)
            }
        }
        #endif
        throw TaskAssistantError.unavailable
    }

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private static func message(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "This task is too long for the on-device model to review."
        case .guardrailViolation:
            return "The on-device model declined to review this task."
        case .unsupportedLanguageOrLocale:
            return "The on-device model doesn't support this language yet."
        case .assetsUnavailable:
            return "The on-device model isn't installed. Check Apple Intelligence in Settings."
        default:
            return "Couldn't review this task on device."
        }
    }
    #endif

    private static let instructions = """
    You review to-do tasks. Given a task's title and description, reply with two to \
    four short sentences covering: whether the task is specific and actionable, what \
    important detail is missing (a due date, acceptance criteria, an owner, a link), \
    and a clearer title if the current one is vague. Plain text only — no markdown, \
    no headings, no bullet points.
    """
}
