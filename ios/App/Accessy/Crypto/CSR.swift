import Foundation
import Security

/// Certificate Signing Request generation
nonisolated class CSR {
    /// Create a Certificate Signing Request in Accessy format
    /// Returns: {base64("axs.1.0")}.{base64(base64(csr_der))}
    static func create(
        keyPair: (privateKey: SecKey, publicKey: SecKey),
        userId: String,
        deviceId: String
    ) throws -> String {
        // Build CSR in DER format
        let csrDer = try buildCSRDER(
            publicKey: keyPair.publicKey,
            privateKey: keyPair.privateKey,
            userId: userId,
            deviceId: deviceId
        )

        // First base64 encoding
        let csrB64Inner = csrDer.base64EncodedString()

        // Second base64 encoding
        let csrB64Outer = Data(csrB64Inner.utf8).base64EncodedString()

        // Encode version header
        let versionB64 = Data("axs.1.0".utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")

        // Remove padding from outer base64
        let csrB64OuterNoPadding = csrB64Outer.replacingOccurrences(of: "=", with: "")

        return "\(versionB64).\(csrB64OuterNoPadding)"
    }

    // MARK: - Private Helpers

    /// Encode length in DER format
    /// Supports short form (<128) and long form (up to 4 bytes = 2^32-1)
    private static func encodeDERLength(_ length: Int) -> Data {
        var data = Data()

        if length < 128 {
            // Short form: length fits in 1 byte
            data.append(UInt8(length))
        } else if length < 256 {
            // Long form: 1 byte for length
            data.append(0x81)
            data.append(UInt8(length))
        } else if length < 65536 {
            // Long form: 2 bytes for length
            data.append(0x82)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        } else if length < 16_777_216 {
            // Long form: 3 bytes for length
            data.append(0x83)
            data.append(UInt8((length >> 16) & 0xFF))
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        } else {
            // Long form: 4 bytes for length (max supported)
            data.append(0x84)
            data.append(UInt8((length >> 24) & 0xFF))
            data.append(UInt8((length >> 16) & 0xFF))
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        }

        return data
    }

    private static func buildCSRDER(
        publicKey: SecKey,
        privateKey: SecKey,
        userId: String,
        deviceId: String
    ) throws -> Data {
        let publicKeyData = try CryptoKeys.exportPublicKeyDER(publicKey: publicKey)

        // Build CertificationRequestInfo
        let certRequestInfo = try buildCertificationRequestInfo(
            publicKeyData: publicKeyData,
            userId: userId,
            deviceId: deviceId
        )

        // Sign the CertificationRequestInfo
        let signature = try signData(certRequestInfo, with: privateKey)

        // Build full CSR: SEQUENCE { certRequestInfo, signatureAlgorithm, signature }
        return try buildFinalCSR(certRequestInfo: certRequestInfo, signature: signature)
    }

    private static func buildCertificationRequestInfo(
        publicKeyData: Data,
        userId: String,
        deviceId: String
    ) throws -> Data {
        var content = Data()

        // Version: INTEGER 0
        content.append(contentsOf: [0x02, 0x01, 0x00])

        // Subject: SEQUENCE { O=userId, CN=deviceId }
        let subject = try buildSubject(userId: userId, deviceId: deviceId)
        content.append(subject)

        // SubjectPublicKeyInfo
        content.append(publicKeyData)

        // Attributes: context-specific [0] (empty)
        content.append(contentsOf: [0xA0, 0x00])

        // Build SEQUENCE with proper length encoding
        var result = Data()
        result.append(0x30)
        result.append(encodeDERLength(content.count))
        result.append(content)

        return result
    }

    private static func buildSubject(userId: String, deviceId: String) throws -> Data {
        var content = Data()

        // O = userId
        try content.append(buildRDN(oid: [0x55, 0x04, 0x0A], value: userId))

        // CN = deviceId
        try content.append(buildRDN(oid: [0x55, 0x04, 0x03], value: deviceId))

        // Build SEQUENCE with proper length encoding
        var result = Data()
        result.append(0x30)
        result.append(encodeDERLength(content.count))
        result.append(content)

        return result
    }

    private static func buildRDN(oid: [UInt8], value: String) throws -> Data {
        // Build SEQUENCE content: OID + PrintableString
        var seqContent = Data()
        seqContent.append(0x06) // OID tag
        seqContent.append(UInt8(oid.count))
        seqContent.append(contentsOf: oid)

        let valueData = Data(value.utf8)
        seqContent.append(0x13) // PrintableString tag
        seqContent.append(UInt8(valueData.count))
        seqContent.append(valueData)

        // Build SEQUENCE
        var sequence = Data()
        sequence.append(0x30)
        sequence.append(encodeDERLength(seqContent.count))
        sequence.append(seqContent)

        // Build SET
        var result = Data()
        result.append(0x31)
        result.append(encodeDERLength(sequence.count))
        result.append(sequence)

        return result
    }

    private static func buildFinalCSR(certRequestInfo: Data, signature: Data) throws -> Data {
        var content = Data()

        // CertificationRequestInfo
        content.append(certRequestInfo)

        // SignatureAlgorithm: SEQUENCE { OID }
        content.append(0x30)
        content.append(0x0A)
        content.append(contentsOf: [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02])

        // Signature: BIT STRING
        content.append(0x03)
        content.append(encodeDERLength(signature.count + 1))
        content.append(0x00) // No unused bits
        content.append(signature)

        // Build outer SEQUENCE with proper length encoding
        var result = Data()
        result.append(0x30)
        result.append(encodeDERLength(content.count))
        result.append(content)

        return result
    }

    private static func signData(_ data: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() ?? CryptoError.keyExportFailed
        }

        // ecdsaSignatureMessageX962SHA256 already returns DER format
        return signature
    }
}
