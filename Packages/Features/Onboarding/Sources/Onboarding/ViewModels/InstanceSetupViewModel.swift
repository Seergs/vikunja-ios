import Foundation
import Observation
import VikunjaCore

/// Drives the "add a connection" screen: the user names an instance, types its
/// address (a bare domain or a full URL, either works) and connects either
/// with an API token or, when the instance reports local auth is enabled,
/// with a username and password (plus a TOTP code, if that account has
/// two-factor enabled). On save, the address is normalized and probed with
/// `GET /api/v1/info` to confirm it's really a Vikunja instance before the
/// connection is persisted and made active.
@MainActor
@Observable
public final class InstanceSetupViewModel {
    public var displayName: String = ""
    public var urlText: String = ""
    public var apiToken: String = ""
    public var credentialMode: InstanceAccount.AuthMethod = .apiToken
    public var username: String = ""
    public var password: String = ""
    public var totpPasscode: String = ""

    public private(set) var validationState: InstanceSetupValidationState = .idle
    public private(set) var savedAccounts: [InstanceAccount] = []
    /// Whether the probed server reports local (username/password) login as
    /// enabled — known only after `testConnection()`/`saveConnection()` has
    /// run once; defaults to `false` so the picker stays hidden until then.
    public private(set) var localAuthAvailable = false
    /// Set when a password login was rejected pending a TOTP code — the view
    /// reveals a code field and `saveConnection()` retries with it filled in.
    public private(set) var awaitingTOTP = false

    /// The account `saveConnection()` most recently persisted — distinct from
    /// `validationState == .success`, which `testConnection()` also reports on
    /// a successful probe. Drives post-save navigation.
    public private(set) var savedAccount: InstanceAccount?

    public var isSaving: Bool {
        validationState == .validating
    }

    private let accountStore: AccountStoreProtocol
    private let clientFactory: InstanceClientFactoryProtocol

    public init(accountStore: AccountStoreProtocol, clientFactory: InstanceClientFactoryProtocol) {
        self.accountStore = accountStore
        self.clientFactory = clientFactory
    }

    public var canSave: Bool {
        guard !trimmedDisplayName.isEmpty, !trimmedURLText.isEmpty, !isSaving else { return false }
        switch credentialMode {
        case .apiToken:
            return !trimmedToken.isEmpty
        case .password:
            return awaitingTOTP ? !trimmedTOTP.isEmpty : (!trimmedUsername.isEmpty && !trimmedPassword.isEmpty)
        }
    }

    public var canTestConnection: Bool {
        !trimmedURLText.isEmpty
    }

    public func loadSavedAccounts() async {
        savedAccounts = await (try? accountStore.fetchAccounts()) ?? []
    }

    /// Probes the typed address without persisting anything — backs a
    /// standalone "test connection" action, distinct from `saveConnection()`.
    public func testConnection() async {
        guard canTestConnection, !isSaving else { return }
        validationState = .validating

        do {
            let baseURL = try InstanceURL.normalize(urlText)
            let provider = clientFactory.makeCapabilityProvider(baseURL: baseURL)
            _ = try await provider.serverInfo()
            localAuthAvailable = await provider.supports(.localAuth)
            validationState = .success
        } catch let error as VikunjaError {
            validationState = .failure(Self.message(for: error))
        } catch {
            validationState = .failure(error.localizedDescription)
        }
    }

    public func saveConnection() async {
        guard canSave, !isSaving else { return }
        validationState = .validating

        do {
            let baseURL = try InstanceURL.normalize(urlText)
            let provider = clientFactory.makeCapabilityProvider(baseURL: baseURL)
            _ = try await provider.serverInfo()
            localAuthAvailable = await provider.supports(.localAuth)

            switch credentialMode {
            case .apiToken:
                let account = InstanceAccount(displayName: trimmedDisplayName, baseURL: baseURL, authMethod: .apiToken)
                try await accountStore.addAccount(account, token: trimmedToken)
                await finishSaving(account)
            case .password:
                await savePasswordAccount(baseURL: baseURL)
            }
        } catch let error as VikunjaError {
            validationState = .failure(Self.message(for: error))
        } catch {
            validationState = .failure(error.localizedDescription)
        }
    }

    private func savePasswordAccount(baseURL: URL) async {
        let coordinator = PasswordLoginCoordinator(authService: clientFactory.makeAuthService(baseURL: baseURL))
        let state = if awaitingTOTP {
            await coordinator.retryWithTOTP(trimmedTOTP, username: trimmedUsername, password: trimmedPassword)
        } else {
            await coordinator.attempt(username: trimmedUsername, password: trimmedPassword)
        }

        switch state {
        case let .success(session):
            let account = InstanceAccount(displayName: trimmedDisplayName, baseURL: baseURL, authMethod: .password)
            do {
                try await accountStore.addAccount(account, token: session.token)
                await finishSaving(account)
            } catch let error as VikunjaError {
                validationState = .failure(Self.message(for: error))
            } catch {
                validationState = .failure(error.localizedDescription)
            }
        case .awaitingTOTP:
            awaitingTOTP = true
            validationState = .idle
        case let .failure(error):
            validationState = .failure(Self.message(for: error))
        case .idle, .authenticating:
            validationState = .idle
        }
    }

    private func finishSaving(_ account: InstanceAccount) async {
        validationState = .success
        savedAccount = account
        resetInputs()
        await loadSavedAccounts()
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedURLText: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedToken: String {
        apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTOTP: String {
        totpPasscode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resetInputs() {
        displayName = ""
        urlText = ""
        apiToken = ""
        username = ""
        password = ""
        totpPasscode = ""
        awaitingTOTP = false
        credentialMode = .apiToken
    }

    private static func message(for error: VikunjaError) -> String {
        switch error {
        case .invalidInstanceURL:
            "That doesn't look like a valid instance address."
        case .network:
            "Couldn't reach that server. Check the address and your connection."
        case .notFound, .decoding:
            "That address didn't respond like a Vikunja instance."
        case .unauthorized:
            "That server rejected the request."
        case let .server(_, statusCode):
            "The server responded with an error (\(statusCode))."
        case let .unsupportedServerVersion(minimumRequired, _):
            "This app needs Vikunja \(minimumRequired) or newer."
        case .totpRequired:
            "This account needs a two-factor code."
        }
    }
}
