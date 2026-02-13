import Foundation
import Security

/// Secure credential storage using iOS Keychain
///
/// iOS Keychain is:
/// - Encrypted by the OS
/// - Persists across app reinstalls
/// - Can be synced via iCloud Keychain (if enabled)
/// - Separate from app sandbox (survives app deletion)
nonisolated final class CredentialsService {
    private let service = "rocks.galaiko.cerve"
    private let credentialsKey = "credentials"
    private let keychainService: KeychainService

    init(keyStore: KeychainService) {
        keychainService = keyStore
    }

    // MARK: - Keychain Operations

    func save(_ credentials: Credentials) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // Available after first unlock
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.notFound : KeychainError.loadFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }

        return try JSONDecoder().decode(Credentials.self, from: data)
    }

    func delete() throws {
        // Load credentials to get key identifiers
        if let credentials = try? load() {
            // Delete associated keys
            try? keychainService.deleteKey(identifier: credentials.loginKeyIdentifier)
            try? keychainService.deleteKey(identifier: credentials.signingKeyIdentifier)
        }

        // Delete credentials
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func exists() -> Bool {
        (try? load()) != nil
    }
}
