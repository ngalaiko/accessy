import Foundation

/// Service for managing access token refresh
/// Mirrors Android app behavior: re-authenticate with crypto proof when token expires
nonisolated final class TokenRefreshService {
    private let apiClient: APIClient
    private let keyStore: KeychainService
    private let credentialsService: CredentialsService
    private let refreshCoordinator = RefreshCoordinator()

    init(apiClient: APIClient, keyStore: KeychainService, credentialsService: CredentialsService) {
        self.apiClient = apiClient
        self.keyStore = keyStore
        self.credentialsService = credentialsService
    }

    /// Get a valid access token, automatically refreshing if expired
    /// - Returns: Valid access token
    /// - Throws: APIError or KeychainError if refresh fails
    func getValidToken() async throws -> String {
        let credentials = try credentialsService.load()

        // Check if token is still valid
        if credentials.isValid {
            return credentials.authToken
        }

        // Token expired - refresh it
        return try await refreshToken(credentials: credentials)
    }

    /// Force refresh the access token by re-authenticating
    /// - Returns: New access token
    /// - Throws: APIError or KeychainError if refresh fails
    func forceRefresh() async throws -> String {
        let credentials = try credentialsService.load()
        return try await refreshToken(credentials: credentials)
    }

    // MARK: - Private

    private func refreshToken(credentials: Credentials) async throws -> String {
        // Use actor to prevent concurrent refresh requests
        return try await refreshCoordinator.refresh { [self] in
            // Load private key from keychain
            let privateKey = try self.keyStore.loadKey(identifier: credentials.loginKeyIdentifier)

            // Create login proof using stored certificate (same as Android deviceLogin)
            let loginProof = try Signing.createProof(
                certBase64: credentials.certBase64,
                privateKey: privateKey
            )

            // Call login endpoint to get new token
            let loginResponse = try await self.apiClient.login(loginProof: loginProof)

            // Update stored credentials with new token
            let updatedCredentials = Credentials(
                authToken: loginResponse.authToken,
                deviceId: credentials.deviceId,
                userId: credentials.userId,
                certBase64: credentials.certBase64,
                isDemoMode: credentials.isDemoMode
            )
            try self.credentialsService.save(updatedCredentials)

            return loginResponse.authToken
        }
    }
}

// MARK: - Refresh Coordinator Actor

/// Actor to coordinate token refresh requests and prevent concurrent refreshes
private actor RefreshCoordinator {
    private var refreshTask: Task<String, Error>?

    func refresh(operation: @escaping () async throws -> String) async throws -> String {
        // If there's already a refresh in progress, wait for it
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        // Start a new refresh task
        let task = Task<String, Error> {
            try await operation()
        }

        refreshTask = task

        defer {
            refreshTask = nil
        }

        return try await task.value
    }
}
