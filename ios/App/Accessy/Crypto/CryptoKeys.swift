import Foundation
import Security

nonisolated enum CryptoError: Error {
    case keyGenerationFailed
    case keyExportFailed
    case keyImportFailed
    case invalidKeyFormat
}

/// EC P-256 (secp256r1) key management
nonisolated class CryptoKeys {
    /// Generate ECDSA P-256 key pair
    static func generateKeyPair() throws -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? CryptoError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoError.keyGenerationFailed
        }

        return (privateKey, publicKey)
    }

    /// Export public key to DER format
    static func exportPublicKeyDER(publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error?.takeRetainedValue() ?? CryptoError.keyExportFailed
        }

        // Wrap in SubjectPublicKeyInfo structure
        return wrapECPublicKeyToSPKI(data)
    }

    // MARK: - Private Helpers

    /// Wrap EC public key in SubjectPublicKeyInfo structure
    private static func wrapECPublicKeyToSPKI(_ rawKey: Data) -> Data {
        var result = Data()

        // SEQUENCE
        result.append(0x30)
        let lengthPlaceholder = result.count
        result.append(0x00) // Will update

        // Algorithm: SEQUENCE
        result.append(0x30)
        result.append(0x13)
        // OID: ecPublicKey
        result.append(contentsOf: [0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01])
        // OID: prime256v1
        result.append(contentsOf: [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07])

        // PublicKey: BIT STRING
        result.append(0x03)
        result.append(UInt8(rawKey.count + 1))
        result.append(0x00) // No unused bits
        result.append(rawKey)

        // Update length
        let contentLength = result.count - lengthPlaceholder - 1
        result[lengthPlaceholder] = UInt8(contentLength)

        return result
    }
}
