import CommonCrypto
import Foundation
import Security

/// ECDH key agreement and shared secret derivation
nonisolated class ECDH {
    // MARK: - Constants

    /// DER structure constants for SPKI (SubjectPublicKeyInfo) format
    /// SPKI structure for P-256 public key:
    /// SEQUENCE (91 bytes total)
    ///   ├─ SEQUENCE (algorithm identifier, 19 bytes)
    ///   └─ BIT STRING (public key, 66 bytes + 1 unused bits byte)
    ///       └─ Raw EC point (65 bytes: 0x04 + 32 bytes X + 32 bytes Y)
    private enum DERConstants {
        // SPKI structure offsets and values
        static let spkiTotalLength = 91
        static let spkiSequenceTag = 0
        static let spkiSequenceLength = 1
        static let spkiContentLength: UInt8 = 0x59 // 89 bytes
        static let spkiBitStringTag = 23
        static let spkiBitStringLength = 24
        static let spkiBitStringContentLength: UInt8 = 0x42 // 66 bytes
        static let spkiUnusedBits = 25
        static let spkiECPointOffset = 26

        // DER tag values
        static let sequenceTag: UInt8 = 0x30
        static let bitStringTag: UInt8 = 0x03
        static let noUnusedBits: UInt8 = 0x00
    }

    /// Perform ECDH key exchange and derive shared secret
    /// Returns SHA-512 hash of shared secret (64 bytes)
    static func deriveSharedSecret(clientPrivateKey: SecKey, serverPublicKeyDER: Data) throws -> Data {
        // Server provides the key in SPKI (SubjectPublicKeyInfo) DER format
        // Parse SPKI to extract the raw EC point

        // Extract raw EC point (65 bytes starting at offset 26)
        let rawECPoint = serverPublicKeyDER.subdata(in: DERConstants.spkiECPointOffset..<DERConstants.spkiTotalLength)

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]

        var error: Unmanaged<CFError>?
        guard let serverPublicKey = SecKeyCreateWithData(rawECPoint as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? CryptoError.keyImportFailed
        }

        return try performECDH(clientPrivateKey: clientPrivateKey, serverPublicKey: serverPublicKey)
    }

    // MARK: - Private Helpers

    private static func performECDH(clientPrivateKey: SecKey, serverPublicKey: SecKey) throws -> Data {
        // Perform ECDH key exchange
        let algorithm = SecKeyAlgorithm.ecdhKeyExchangeStandard
        guard SecKeyIsAlgorithmSupported(clientPrivateKey, .keyExchange, algorithm) else {
            throw CryptoError.keyExportFailed
        }

        var exchangeError: Unmanaged<CFError>?
        guard let sharedSecret = SecKeyCopyKeyExchangeResult(
            clientPrivateKey,
            algorithm,
            serverPublicKey,
            [:] as CFDictionary,
            &exchangeError
        ) as Data? else {
            throw exchangeError?.takeRetainedValue() ?? CryptoError.keyExportFailed
        }

        // Hash with SHA-512
        return sha512(sharedSecret)
    }

    /// Wrap raw EC public key (65 bytes uncompressed point) in SPKI structure
    private static func wrapRawECPublicKeyToSPKI(_ rawKey: Data) -> Data {
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

    private static func sha512(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA512(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}
