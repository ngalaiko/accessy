import SwiftUI

// MARK: - Environment Keys for Services

// Note: Default values are provided for EnvironmentKey protocol conformance
// but should never be used - services are always injected at app level

private struct KeychainKeyStoreKey: EnvironmentKey {
    static let defaultValue = KeychainService()
}

private struct CredentialsStoreKey: EnvironmentKey {
    static let defaultValue = CredentialsService(keyStore: KeychainService())
}

private struct APIClientKey: EnvironmentKey {
    static let defaultValue = APIClient()
}

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue = AuthService(
        apiClient: APIClient(),
        keyStore: KeychainService()
    )
}

private struct DoorsServiceKey: EnvironmentKey {
    static let defaultValue: DoorsService = {
        let keyStore = KeychainService()
        let credentialsService = CredentialsService(keyStore: keyStore)
        let apiClient = APIClient()
        let tokenRefreshService = TokenRefreshService(
            apiClient: apiClient,
            keyStore: keyStore,
            credentialsService: credentialsService
        )
        return DoorsService(
            apiClient: apiClient,
            keyStore: keyStore,
            tokenRefreshService: tokenRefreshService
        )
    }()
}

// MARK: - EnvironmentValues Extensions

extension EnvironmentValues {
    var keyStore: KeychainService {
        get { self[KeychainKeyStoreKey.self] }
        set { self[KeychainKeyStoreKey.self] = newValue }
    }

    var credentialsStore: CredentialsService {
        get { self[CredentialsStoreKey.self] }
        set { self[CredentialsStoreKey.self] = newValue }
    }

    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    var doorsService: DoorsService {
        get { self[DoorsServiceKey.self] }
        set { self[DoorsServiceKey.self] = newValue }
    }
}
