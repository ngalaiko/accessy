import Foundation

// MARK: - Verification

struct VerifyRequest: Codable {
    let msisdn: String
}

struct VerifyResponse: Codable {
    let verificationCodeId: String
}

// MARK: - Enrollment Token

struct EnrollTokenRequest: Codable {
    let code: String
    let id: String
}

struct EnrollTokenResponse: Codable {
    let token: String
    let recoveryKeyRequired: Bool
}

// MARK: - Recovery Key

struct ValidateRecoveryRequest: Codable {
    let recoveryKey: String
}

struct ValidateRecoveryResponse: Codable {
    let valid: Bool
}

// MARK: - Device Enrollment

struct EnrollRequest: Codable {
    let deviceName: String
    let recoveryKey: String?
    let csrForSigning: String
    let csrForLogin: String
    let appName: String
}

struct EnrollResponse: Codable {
    let certificateForLogin: String
    let certificateForSigning: String
}

// MARK: - Login

struct LoginResponse: Codable {
    let authToken: String

    enum CodingKeys: String, CodingKey {
        case authToken = "auth_token"
    }
}

// MARK: - JWT Payload

struct JWTPayload: Codable {
    let jti: String?
    let sub: String?
    let iss: String?
    let exp: Int?
    let iat: Int?
    let deviceId: String?
    let publicKeyForLogin: String?
}

// MARK: - Credentials

/// Credentials stored securely in Keychain
/// Note: Private keys are stored separately using KeychainKeyStore
struct Credentials: Codable {
    let authToken: String
    let deviceId: String
    let userId: String
    let certBase64: String
    let isDemoMode: Bool

    // Key identifiers for looking up SecKey in Keychain
    var loginKeyIdentifier: String { "login-\(deviceId)" }
    var signingKeyIdentifier: String { "signing-\(deviceId)" }

    /// Check if the access token is expired
    var isExpired: Bool {
        JWT.isExpired(authToken)
    }

    /// Check if the access token is still valid (not expired)
    var isValid: Bool {
        JWT.isValid(authToken)
    }

    init(authToken: String, deviceId: String, userId: String, certBase64: String, isDemoMode: Bool = false) {
        self.authToken = authToken
        self.deviceId = deviceId
        self.userId = userId
        self.certBase64 = certBase64
        self.isDemoMode = isDemoMode
    }
}
