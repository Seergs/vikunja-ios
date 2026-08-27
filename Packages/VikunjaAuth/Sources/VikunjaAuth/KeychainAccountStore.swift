import Foundation
import VikunjaCore

/// Keychain-backed `AccountStoreProtocol`. Account metadata (id, display name,
/// base URL) and the active-account pointer are stored as JSON/plain strings;
/// each account's bearer token is stored as its own item, keyed by account id,
/// so removing an account can drop its secret without touching the others.
public actor KeychainAccountStore: AccountStoreProtocol {
    private let service: String
    private let indexAccount = "instance-accounts-index"
    private let activeAccountItem = "active-account-id"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(service: String = "dev.sergiosuarez.vikunja.accounts") {
        self.service = service

        // This JSON never leaves the device (unlike the wire DTOs in
        // VikunjaNetworking, which use `.iso8601` to match the server). Dates
        // are encoded as the raw bit pattern of their underlying `Double` so
        // `createdAt` round-trips exactly — `.iso8601` truncates to whole
        // seconds, and `.secondsSince1970`/`.millisecondsSince1970` round-trip
        // the `Double` through JSON text, which loses precision.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate.bitPattern)
        }
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let bitPattern = try container.decode(UInt64.self)
            return Date(timeIntervalSinceReferenceDate: Double(bitPattern: bitPattern))
        }
        self.decoder = decoder
    }

    public func fetchAccounts() throws -> [InstanceAccount] {
        try loadIndex()
    }

    public func activeAccount() throws -> InstanceAccount? {
        guard let id = try readActiveAccountID() else { return nil }
        return try loadIndex().first { $0.id == id }
    }

    public func addAccount(_ account: InstanceAccount, token: String) throws {
        var accounts = try loadIndex()
        accounts.removeAll { $0.id == account.id }
        accounts.append(account)
        try saveIndex(accounts)

        try Keychain.save(Data(token.utf8), service: service, account: tokenItem(for: account.id))
        try writeActiveAccountID(account.id)
    }

    public func updateAccount(_ account: InstanceAccount, token: String?) throws {
        var accounts = try loadIndex()
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            throw VikunjaError.notFound
        }
        accounts[index] = account
        try saveIndex(accounts)

        if let token {
            try Keychain.save(Data(token.utf8), service: service, account: tokenItem(for: account.id))
        }
    }

    public func removeAccount(id: InstanceAccount.ID) throws {
        var accounts = try loadIndex()
        accounts.removeAll { $0.id == id }
        try saveIndex(accounts)
        try Keychain.delete(service: service, account: tokenItem(for: id))

        if try readActiveAccountID() == id {
            try Keychain.delete(service: service, account: activeAccountItem)
            if let next = accounts.first {
                try writeActiveAccountID(next.id)
            }
        }
    }

    public func setActiveAccount(id: InstanceAccount.ID) throws {
        guard try loadIndex().contains(where: { $0.id == id }) else {
            throw VikunjaError.notFound
        }
        try writeActiveAccountID(id)
    }

    public func token(forAccountID id: InstanceAccount.ID) throws -> String? {
        guard let data = try Keychain.read(service: service, account: tokenItem(for: id)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private

    private func tokenItem(for id: InstanceAccount.ID) -> String {
        "instance-token-\(id.uuidString)"
    }

    private func loadIndex() throws -> [InstanceAccount] {
        guard let data = try Keychain.read(service: service, account: indexAccount) else { return [] }
        return try decoder.decode([InstanceAccount].self, from: data)
    }

    private func saveIndex(_ accounts: [InstanceAccount]) throws {
        try Keychain.save(try encoder.encode(accounts), service: service, account: indexAccount)
    }

    private func readActiveAccountID() throws -> UUID? {
        guard let data = try Keychain.read(service: service, account: activeAccountItem),
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return UUID(uuidString: string)
    }

    private func writeActiveAccountID(_ id: UUID) throws {
        try Keychain.save(Data(id.uuidString.utf8), service: service, account: activeAccountItem)
    }
}
