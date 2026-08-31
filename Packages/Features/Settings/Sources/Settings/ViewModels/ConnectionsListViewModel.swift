import Foundation
import Observation
import VikunjaCore

/// Drives the "Connections" screen: lists every saved instance and lets the
/// user switch which one is active. Deleting a connection happens from
/// within its own edit screen (`ConnectionFormViewModel.deleteConnection`),
/// not from this list.
@MainActor
@Observable
public final class ConnectionsListViewModel {
    public private(set) var accounts: [InstanceAccount] = []
    public private(set) var activeAccountID: InstanceAccount.ID?
    public private(set) var loadState: ScreenLoadState = .idle

    public var isLoading: Bool {
        loadState == .loading
    }

    private let accountStore: AccountStoreProtocol
    private let toastPresenter: ToastPresenting
    /// Fired after `setActive` may have changed which account is active, so
    /// the app target can rebuild the main tab shell against the new one.
    private let onActiveAccountChanged: () -> Void

    public init(
        accountStore: AccountStoreProtocol,
        toastPresenter: ToastPresenting,
        onActiveAccountChanged: @escaping () -> Void,
    ) {
        self.accountStore = accountStore
        self.toastPresenter = toastPresenter
        self.onActiveAccountChanged = onActiveAccountChanged
    }

    public func load() async {
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            accounts = try await accountStore.fetchAccounts()
            activeAccountID = try await accountStore.activeAccount()?.id
            loadState = .loaded
        } catch let error as VikunjaError {
            loadState = .failure(error.displayMessage)
        } catch {
            loadState = .failure(error.localizedDescription)
        }
    }

    public func setActive(_ account: InstanceAccount) async {
        guard account.id != activeAccountID else { return }
        do {
            try await accountStore.setActiveAccount(id: account.id)
            activeAccountID = account.id
            onActiveAccountChanged()
        } catch let error as VikunjaError {
            toastPresenter.show(error.displayMessage, style: .error)
        } catch {
            toastPresenter.show(error.localizedDescription, style: .error)
        }
    }
}
