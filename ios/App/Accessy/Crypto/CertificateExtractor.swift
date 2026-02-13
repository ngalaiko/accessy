import Foundation
import Security

/// Utility for extracting and decrypting certificates from enrollment responses
nonisolated class CertificateExtractor {
    /// Extract and decrypt certificate from encrypted enrollment response
    ///
    /// The certificate format is: {header}.{metadata}.{serverPubKey}.{encryptedData}.{signature}
    /// The encrypted data contains: {iv}.{ciphertext}.{hmac}
    static func extractCertificate(
        from certificateForLogin: String,
        using privateKey: SecKey
    ) throws -> String? {
        let parts = certificateForLogin.split(separator: ".")
        guard parts.count >= 5 else {
            return nil
        }

        // Part 2: Server's ephemeral public key
        let serverPubKeyB64 = String(parts[2])
        guard let serverPubKeyDER = Encryption.safeB64Decode(serverPubKeyB64) else {
            return nil
        }

        // Part 3: Encrypted certificate data
        let certDataB64 = String(parts[3])
        guard let certDataBytes = Encryption.safeB64Decode(certDataB64),
              let certDataStr = String(data: certDataBytes, encoding: .utf8) else {
            return nil
        }

        guard certDataStr.contains(".") else {
            return nil
        }

        let certParts = certDataStr.split(separator: ".")
        guard certParts.count == 3 else {
            return nil
        }

        // Format: {iv}.{encrypted}.{hmac}
        let ivBase64 = String(certParts[0])
        let encryptedBase64 = String(certParts[1])
        let hmacBase64 = String(certParts[2])

        guard let initializationVector = Encryption.safeB64Decode(ivBase64),
              let encryptedData = Encryption.safeB64Decode(encryptedBase64),
              let hmacTag = Encryption.safeB64Decode(hmacBase64) else {
            return nil
        }

        // Decrypt certificate using ECDH + AES-256-CBC
        return try Encryption.decryptCertificate(
            encryptedCert: encryptedData,
            iv: initializationVector,
            hmacTag: hmacTag,
            serverEphemeralPublicKeyDER: serverPubKeyDER,
            clientPrivateKey: privateKey,
            ivB64Original: ivBase64,
            ciphertextB64Original: encryptedBase64
        )
    }
}
