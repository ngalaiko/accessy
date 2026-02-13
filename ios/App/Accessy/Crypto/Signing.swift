import CommonCrypto
import Foundation
import Security

/// ECDSA signing and proof creation
nonisolated class Signing {
    /// Create authentication proof in format: {header}.{certificate}.{payload}.{signature}
    static func createProof(certBase64: String, privateKey: SecKey) throws -> String {
        // Step 1: Generate header
        let header = base64URLEncode(Data("axs.1.4".utf8))

        // Step 2: Encode certificate
        let certificate = base64URLEncode(Data(certBase64.utf8))

        // Step 3: Generate payload - timestamp rounded to nearest 5 seconds
        let currentTime = Int(Date().timeIntervalSince1970)
        let roundedTime = currentTime - (currentTime % 5)
        let timestampStr = String(roundedTime)
        let payload = base64URLEncode(Data(timestampStr.utf8))

        // Step 4: Sign the data (header.certificate.payload)
        let dataToSign = "\(header).\(certificate).\(payload)"
        let signature = try signData(dataToSign, with: privateKey)

        // Step 5: Build final proof
        return "\(header).\(certificate).\(payload).\(signature)"
    }

    // MARK: - Private Helpers

    /// Sign data with ECDSA-SHA256 and return base64url signature
    private static func signData(_ data: String, with privateKey: SecKey) throws -> String {
        guard let dataBytes = data.data(using: .utf8) else {
            throw CryptoError.invalidKeyFormat
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            dataBytes as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() ?? CryptoError.keyExportFailed
        }

        // ecdsaSignatureMessageX962SHA256 already returns DER format
        // Convert to base64url
        return base64URLEncode(signature)
    }

    /// Convert data to URL-safe base64 without padding
    private static func base64URLEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
