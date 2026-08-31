import Foundation
import Observation
import VikunjaCore

/// Drives the "add a connection" screen: the user names an instance, types its
/// address (a bare domain or a full URL, either works) and an API token. On
/// save, the address is normalized and probed with `GET /api/v1/info` to
/// confirm it's really a Vikunja instance before the connection is persisted
/// and made active — the token itself isn't validated against the server yet.
@MainActor
@Observable
public final class InstanceSetupViewModel {
    public var displayName: String = ""
    public var urlText: String = ""
    public var apiToken: String = ""

    public private(set) var validationState: InstanceSetupValidationState = .idle
    public private(set) var savedAccounts: [InstanceAccount] = []

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
        !trimmedDisplayName.isEmpty && !trimmedURLText.isEmpty && !trimmedToken.isEmpty
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
            _ = try await clientFactory.makeCapabilityProvider(baseURL: baseURL).serverInfo()
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
            _ = try await clientFactory.makeCapabilityProvider(baseURL: baseURL).serverInfo()

            let account = InstanceAccount(displayName: trimmedDisplayName, baseURL: baseURL)
            try await accountStore.addAccount(account, token: trimmedToken)

            validationState = .success
            savedAccount = account
            resetInputs()
            await loadSavedAccounts()
        } catch let error as VikunjaError {
            validationState = .failure(Self.message(for: error))
        } catch {
            validationState = .failure(error.localizedDescription)
        }
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

    private func resetInputs() {
        displayName = ""
        urlText = ""
        apiToken = ""
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
        }
    }
}
