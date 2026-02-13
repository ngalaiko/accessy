import CommonCrypto
import Foundation
import Security

/// Certificate decryption using AES-256-CBC + HMAC-SHA256
nonisolated class Encryption {
    /// Decrypt certificate using AES-256-CBC + HMAC-SHA256 with ECDH-derived key
    static func decryptCertificate(
        encryptedCert: Data,
        iv: Data,
        hmacTag: Data,
        serverEphemeralPublicKeyDER: Data,
        clientPrivateKey: SecKey,
        ivB64Original: String,
        ciphertextB64Original: String
    ) throws -> String {
        // Step 1-3: Derive shared secret and hash with SHA-512
        let derivedKey = try ECDH.deriveSharedSecret(
            clientPrivateKey: clientPrivateKey,
            serverPublicKeyDER: serverEphemeralPublicKeyDER
        )

        // Step 4: Split key
        let aesKey = derivedKey.prefix(32) // First 32 bytes for AES-256
        let hmacKey = derivedKey.suffix(32) // Last 32 bytes for HMAC-SHA256

        // Step 5: Verify HMAC over original base64 strings
        let dataToVerify = Data("\(ivB64Original).\(ciphertextB64Original)".utf8)
        let expectedHmac = computeHMACSHA256(data: dataToVerify, key: hmacKey)

        guard constantTimeEqual(expectedHmac, hmacTag) else {
            throw CryptoError.keyImportFailed
        }

        // Step 6: Decrypt with AES-256-CBC
        let plaintext = try decryptAES256CBC(data: encryptedCert, key: aesKey, iv: iv)

        // Step 7: Convert to string
        guard let plaintextStr = String(data: plaintext, encoding: .ascii) else {
            throw CryptoError.keyImportFailed
        }

        return plaintextStr
    }

    // MARK: - Private Helpers

    private static func decryptAES256CBC(data: Data, key: Data, iv: Data) throws -> Data {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted: size_t = 0

        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            data.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard cryptStatus == kCCSuccess else {
            throw CryptoError.keyExportFailed
        }

        buffer.count = numBytesDecrypted
        return buffer
    }

    private static func computeHMACSHA256(data: Data, key: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    key.count,
                    dataBytes.baseAddress,
                    data.count,
                    &hmac
                )
            }
        }
        return Data(hmac)
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var result: UInt8 = 0
        for index in 0..<lhs.count {
            result |= lhs[index] ^ rhs[index]
        }
        return result == 0
    }

    /// Helper: Decode URL-safe base64 with proper padding
    static func safeB64Decode(_ base64String: String) -> Data? {
        var normalizedString = base64String.replacingOccurrences(of: "-", with: "+").replacingOccurrences(
            of: "_",
            with: "/"
        )
        let padding = 4 - (normalizedString.count % 4)
        if padding != 4 {
            normalizedString += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: normalizedString)
    }
}
