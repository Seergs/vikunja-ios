import Foundation
import Observation
import VikunjaCore

/// Drives the "add/edit connection" screen (`ConnectionFormMode.create` or
/// `.edit`). Mirrors `Onboarding`'s `InstanceSetupViewModel` — same
/// normalize-then-probe-`/api/v1/info` flow — but assumes at least one
/// connection already exists (there's always a `ConnectionsListView` to
/// return to), and additionally supports editing and deleting an existing
/// connection.
///
/// Saving always re-probes the server, in both modes: editing a connection
/// is exactly as likely to introduce a typo'd URL as creating one, so there's
/// no reason to trust an unchanged-looking field over a freshly typed one.
@MainActor
@Observable
public final class ConnectionFormViewModel {
    public let mode: ConnectionFormMode

    public var displayName: String = ""
    public var urlText: String = ""
    public var apiToken: String = ""

    public private(set) var validationState: ConnectionValidationState = .idle
    /// The account `save()` most recently persisted — distinct from
    /// `validationState == .success`, which `testConnection()` also reports
    /// on a successful probe. Drives post-save dismissal.
    public private(set) var savedAccount: InstanceAccount?

    public var isSaving: Bool {
        validationState == .validating
    }

    public var isEditing: Bool {
        if case .edit = mode {
            true
        } else {
            false
        }
    }

    public var canSave: Bool {
        !trimmedDisplayName.isEmpty && !trimmedURLText.isEmpty && !trimmedToken.isEmpty && !isSaving
    }

    public var canTestConnection: Bool {
        !trimmedURLText.isEmpty && !isSaving
    }

    private let accountStore: AccountStoreProtocol
    private let clientFactory: InstanceClientFactoryProtocol
    private let toastPresenter: ToastPresenting
    /// Fired after a save/delete that may have changed which account is
    /// active, or edited the active account's own address — either way the
    /// app target needs to rebuild the main tab shell. See
    /// `ConnectionsListViewModel`'s copy of the same reasoning.
    private let onActiveAccountChanged: () -> Void

    public init(
        mode: ConnectionFormMode,
        accountStore: AccountStoreProtocol,
        clientFactory: InstanceClientFactoryProtocol,
        toastPresenter: ToastPresenting,
        onActiveAccountChanged: @escaping () -> Void,
    ) {
        self.mode = mode
        self.accountStore = accountStore
        self.clientFactory = clientFactory
        self.toastPresenter = toastPresenter
        self.onActiveAccountChanged = onActiveAccountChanged

        if case let .edit(account) = mode {
            self.displayName = account.displayName
            self.urlText = account.baseURL.absoluteString
        }
    }

    /// Fills in the existing token for `.edit` mode. Separate from `init`
    /// since reading it is async (Keychain) — the form renders immediately
    /// with name/URL already populated and the token field fills in a moment
    /// later, same as any other server-backed load in this app.
    public func load() async {
        guard case let .edit(account) = mode else { return }
        apiToken = await (try? accountStore.token(forAccountID: account.id)) ?? ""
    }

    /// Probes the typed address without persisting anything — backs a
    /// standalone "test connection" action, distinct from `save()`.
    public func testConnection() async {
        guard canTestConnection else { return }
        validationState = .validating
        do {
            let baseURL = try InstanceURL.normalize(urlText)
            _ = try await clientFactory.makeCapabilityProvider(baseURL: baseURL).serverInfo()
            validationState = .success
        } catch let error as VikunjaError {
            validationState = .failure(error.displayMessage)
        } catch {
            validationState = .failure(error.localizedDescription)
        }
    }

    public func save() async {
        guard canSave else { return }
        validationState = .validating
        do {
            let baseURL = try InstanceURL.normalize(urlText)
            _ = try await clientFactory.makeCapabilityProvider(baseURL: baseURL).serverInfo()

            switch mode {
            case .create:
                let account = InstanceAccount(displayName: trimmedDisplayName, baseURL: baseURL)
                try await accountStore.addAccount(account, token: trimmedToken)
                savedAccount = account
                toastPresenter.show("Connection added", style: .success)
            case let .edit(original):
                var account = original
                account.displayName = trimmedDisplayName
                account.baseURL = baseURL
                try await accountStore.updateAccount(account, token: trimmedToken)
                savedAccount = account
                toastPresenter.show("Connection updated", style: .success)
            }
            validationState = .success
            onActiveAccountChanged()
        } catch let error as VikunjaError {
            validationState = .failure(error.displayMessage)
        } catch {
            validationState = .failure(error.localizedDescription)
        }
    }

    /// Deletes the connection being edited. No-op outside `.edit` mode.
    /// Refuses (with a toast) to delete the last remaining connection —
    /// there always has to be one active account for the main tab shell to
    /// render against.
    @discardableResult
    public func deleteConnection() async -> Bool {
        guard case let .edit(account) = mode else { return false }
        do {
            let remaining = try await accountStore.fetchAccounts()
            guard remaining.count > 1 else {
                toastPresenter.show("You need at least one connection", style: .error)
                return false
            }
            let activeID = try await accountStore.activeAccount()?.id
            try await accountStore.removeAccount(id: account.id)
            toastPresenter.show("Connection removed", style: .success)
            if activeID == account.id {
                onActiveAccountChanged()
            }
            return true
        } catch let error as VikunjaError {
            toastPresenter.show(error.displayMessage, style: .error)
            return false
        } catch {
            toastPresenter.show(error.localizedDescription, style: .error)
            return false
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
}
