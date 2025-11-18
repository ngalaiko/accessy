import Foundation

/// JWT decoding utilities
class JWT {
    /// Decode JWT payload without verification (server already verified)
    static func decodePayload(_ token: String) throws -> JWTPayload {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else {
            throw CryptoError.invalidKeyFormat
        }

        let payloadPart = String(parts[1])
        guard let data = Encryption.safeB64Decode(payloadPart) else {
            throw CryptoError.invalidKeyFormat
        }

        let decoder = JSONDecoder()
        return try decoder.decode(JWTPayload.self, from: data)
    }

    /// Check if JWT token is expired
    /// - Parameter token: The JWT token string
    /// - Returns: true if token is expired, false if valid
    static func isExpired(_ token: String) -> Bool {
        guard let payload = try? decodePayload(token),
              let exp = payload.exp else {
            // If we can't decode or no expiration, consider it expired
            return true
        }

        let expirationDate = Date(timeIntervalSince1970: TimeInterval(exp))
        return expirationDate <= Date()
    }

    /// Check if JWT token is valid (not expired)
    /// - Parameter token: The JWT token string
    /// - Returns: true if token is valid, false if expired
    static func isValid(_ token: String) -> Bool {
        return !isExpired(token)
    }
}
