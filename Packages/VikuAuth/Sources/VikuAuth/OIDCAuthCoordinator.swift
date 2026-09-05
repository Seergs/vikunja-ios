import AppAuth
import VikunjaCore

#if canImport(UIKit)
import UIKit
#endif

public enum OIDCAuthError: Error, Sendable, Equatable {
    /// No foreground window to present the authorization page from.
    case noPresentingViewController
    /// `ASWebAuthenticationSession` couldn't be started (e.g. Guided Access
    /// is on).
    case presentationUnavailable
    case missingAuthorizationCode
    /// This platform has no system browser session to present (the macOS
    /// unit-test host).
    case unsupportedPlatform
}

/// Presents an OIDC provider's authorization page in `ASWebAuthenticationSession`
/// (via AppAuth) and returns the resulting authorization code. Never contacts
/// a token endpoint itself — Vikunja's backend does that exchange server-side
/// (see `AuthServiceProtocol.loginWithOIDC`), so `OIDServiceConfiguration`'s
/// required `tokenEndpoint` is filled with a value that's never dereferenced.
@MainActor
public final class OIDCAuthCoordinator: OIDCAuthenticating {
    #if canImport(UIKit)
    private var currentSession: OIDExternalUserAgentSession?
    #endif

    public init() {}

    public func authenticate(provider: OIDCProvider, redirectURI: URL) async throws -> String {
        #if canImport(UIKit)
        guard let presentingViewController = Self.foregroundPresentingViewController() else {
            throw OIDCAuthError.noPresentingViewController
        }
        guard let agent = OIDExternalUserAgentIOS(presenting: presentingViewController) else {
            throw OIDCAuthError.presentationUnavailable
        }

        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: provider.authURL,
            tokenEndpoint: provider.authURL,
        )
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: provider.clientID,
            scopes: provider.scope.split(separator: " ").map(String.init),
            redirectURL: redirectURI,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil,
        )

        return try await withCheckedThrowingContinuation { continuation in
            currentSession = OIDAuthorizationService.present(
                request,
                externalUserAgent: agent,
            ) { [weak self] response, error in
                self?.currentSession = nil
                if let code = response?.authorizationCode {
                    continuation.resume(returning: code)
                } else {
                    continuation.resume(throwing: error ?? OIDCAuthError.missingAuthorizationCode)
                }
            }
        }
        #else
        throw OIDCAuthError.unsupportedPlatform
        #endif
    }

    /// Cancels an in-flight authentication, if any — e.g. the presenting
    /// screen was dismissed before the user finished.
    public func cancel() {
        #if canImport(UIKit)
        currentSession?.cancel()
        currentSession = nil
        #endif
    }

    #if canImport(UIKit)
    private static func foregroundPresentingViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController
    }
    #endif
}
