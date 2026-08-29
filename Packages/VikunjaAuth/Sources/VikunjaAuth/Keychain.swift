import Foundation
import Security

/// Thin wrapper over Keychain Services generic password items. Internal —
/// `KeychainAccountStore` is the only consumer.
///
/// Every call takes an optional `accessGroup`: when set (to a
/// `keychain-access-group` both the app and its widget extension list in
/// their entitlements), the item is written into that shared group so the
/// widget process can read the same credentials. When `nil`, items land in
/// the app's private default group, exactly as before.
enum Keychain {
    enum KeychainError: Error, LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .unexpectedStatus(status):
                let message = SecCopyErrorMessageString(status, nil) as String?
                return "Keychain error \(status)" + (message.map { ": \($0)" } ?? "")
            }
        }
    }

    static func save(_ data: Data, service: String, account: String, accessGroup: String? = nil) throws {
        let query = query(service: service, account: account, accessGroup: accessGroup)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func read(service: String, account: String, accessGroup: String? = nil) throws -> Data? {
        var query = query(service: service, account: account, accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func delete(service: String, account: String, accessGroup: String? = nil) throws {
        let status = SecItemDelete(query(service: service, account: account, accessGroup: accessGroup) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func query(service: String, account: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
