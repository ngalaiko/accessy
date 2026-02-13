import Foundation
import Security

nonisolated enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case decodingFailed
}

nonisolated final class KeychainService {
    private let service = "rocks.galaiko.cerve.keys"
    private let accessGroup = "5S3AM79MK3.rocks.galaiko.cerve"

    init() {}

    // MARK: - Key Storage

    func saveKey(_ key: SecKey, identifier: String) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(identifier.utf8),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecValueRef as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccessGroup as String: accessGroup
        ]

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(identifier.utf8),
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func loadKey(identifier: String) throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(identifier.utf8),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecAttrAccessGroup as String: accessGroup
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyRef = result else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.loadFailed(status)
        }

        // SecKey is a CoreFoundation type (opaque pointer)
        // When kSecReturnRef is true, the result is guaranteed to be SecKey
        // swiftlint:disable:next force_cast
        return (keyRef as! SecKey)
    }

    func deleteKey(identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(identifier.utf8),
            kSecAttrAccessGroup as String: accessGroup
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func keyExists(identifier: String) -> Bool {
        (try? loadKey(identifier: identifier)) != nil
    }
}
