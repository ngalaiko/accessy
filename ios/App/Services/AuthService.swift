import Foundation
import Security

/// Service for authentication operations
nonisolated final class AuthService {
    private let apiClient: APIClient
    private let keyStore: KeychainService

    init(apiClient: APIClient, keyStore: KeychainService) {
        self.apiClient = apiClient
        self.keyStore = keyStore
    }

    // MARK: - Authentication Flow

    /// Request SMS verification code
    func requestVerificationCode(phoneNumber: String) async throws -> String {
        // Demo mode: accept demo phone numbers
        if DemoData.isDemoPhoneNumber(phoneNumber) {
            return "demo-verification-id"
        }

        let response = try await apiClient.requestVerification(msisdn: phoneNumber)
        return response.verificationCodeId
    }

    /// Submit verification code and get enrollment token
    func submitVerificationCode(code: String, verificationCodeId: String) async throws -> EnrollmentToken {
        // Demo mode: accept any code for demo verification ID
        if verificationCodeId == "demo-verification-id" {
            return EnrollmentToken(
                token: "demo-enroll-token",
                recoveryKeyRequired: false,
                userId: "demo-user-id",
                deviceId: "demo-device-id"
            )
        }

        let response = try await apiClient.submitVerificationCode(code: code, id: verificationCodeId)

        // Decode JWT to extract user/device info
        let payload = try JWT.decodePayload(response.token)
        let userId = payload.jti ?? payload.sub ?? ""
        let deviceId = payload.deviceId ?? ""

        return EnrollmentToken(
            token: response.token,
            recoveryKeyRequired: response.recoveryKeyRequired,
            userId: userId,
            deviceId: deviceId
        )
    }

    /// Validate recovery key
    func validateRecoveryKey(recoveryKey: String, enrollToken: String) async throws -> Bool {
        // Demo mode: accept any recovery key
        if enrollToken == "demo-enroll-token" {
            return true
        }

        let response = try await apiClient.validateRecoveryKey(recoveryKey: recoveryKey, enrollToken: enrollToken)
        return response.valid
    }

    /// Enroll device and complete login flow
    /// Returns credentials that should be stored securely
    func enrollDeviceAndLogin(
        deviceName: String,
        recoveryKey: String?,
        enrollToken: EnrollmentToken
    ) async throws -> Credentials {
        // Demo mode: return demo credentials without any crypto operations
        if enrollToken.token == "demo-enroll-token" {
            return DemoData.createDemoCredentials()
        }

        // Generate key pairs on device
        let signingKeyPair = try CryptoKeys.generateKeyPair()
        let loginKeyPair = try CryptoKeys.generateKeyPair()

        // Create certificate signing requests
        let csrForSigning = try CSR.create(
            keyPair: signingKeyPair,
            userId: enrollToken.userId,
            deviceId: enrollToken.deviceId
        )
        let csrForLogin = try CSR.create(
            keyPair: loginKeyPair,
            userId: enrollToken.userId,
            deviceId: enrollToken.deviceId
        )

        // Enroll device with server
        let enrollRequest = EnrollRequest(
            deviceName: deviceName,
            recoveryKey: recoveryKey,
            csrForSigning: csrForSigning,
            csrForLogin: csrForLogin,
            appName: "Cerve-iOS"
        )

        let enrollResponse = try await apiClient.enrollDevice(
            request: enrollRequest,
            enrollToken: enrollToken.token
        )

        // Extract and decrypt device certificate
        guard let certBase64 = try CertificateExtractor.extractCertificate(
            from: enrollResponse.certificateForLogin,
            using: loginKeyPair.privateKey
        ) else {
            throw AuthServiceError.certificateExtractionFailed
        }

        // Create login proof and authenticate
        let loginProof = try Signing.createProof(certBase64: certBase64, privateKey: loginKeyPair.privateKey)
        let loginResponse = try await apiClient.login(loginProof: loginProof)

        // Update certificate from JWT if provided
        let jwtPayload = try JWT.decodePayload(loginResponse.authToken)
        let finalCert = jwtPayload.publicKeyForLogin ?? certBase64

        // Create credentials (keys will be stored separately)
        let credentials = Credentials(
            authToken: loginResponse.authToken,
            deviceId: enrollToken.deviceId,
            userId: enrollToken.userId,
            certBase64: finalCert
        )

        // Store private keys in Keychain using Apple's recommended approach
        try keyStore.saveKey(loginKeyPair.privateKey, identifier: credentials.loginKeyIdentifier)
        try keyStore.saveKey(signingKeyPair.privateKey, identifier: credentials.signingKeyIdentifier)

        return credentials
    }
}

// MARK: - Supporting Types

nonisolated struct EnrollmentToken {
    let token: String
    let recoveryKeyRequired: Bool
    let userId: String
    let deviceId: String
}

nonisolated enum AuthServiceError: Error {
    case certificateExtractionFailed
}
