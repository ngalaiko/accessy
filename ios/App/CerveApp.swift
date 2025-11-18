import Combine
import SwiftUI

@main
struct CerveApp: App {
    // Create service instances
    private let keyStore: KeychainService
    private let credentialsStore: CredentialsService
    private let apiClient: APIClient
    private let authService: AuthService
    private let doorsService: DoorsService

    // ObservableObject managers and view models
    @StateObject private var locationManager: LocationManager
    @StateObject private var nearestDoorManager: NearestDoorManager
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var doorsViewModel: DoorsViewModel

    init() {
        // Initialize storage and API layers
        let keyStore = KeychainService()
        let credentialsStore = CredentialsService(keyStore: keyStore)
        let apiClient = APIClient()

        // Initialize token refresh service
        let tokenRefreshService = TokenRefreshService(
            apiClient: apiClient,
            keyStore: keyStore,
            credentialsService: credentialsStore
        )

        // Initialize services
        let authService = AuthService(apiClient: apiClient, keyStore: keyStore)
        let doorsService = DoorsService(
            apiClient: apiClient,
            keyStore: keyStore,
            tokenRefreshService: tokenRefreshService
        )

        // Initialize managers and view models
        let locationManager = LocationManager()
        let nearestDoorManager = NearestDoorManager(doorsService: doorsService)
        let authViewModel = AuthViewModel(authService: authService, credentialsStore: credentialsStore)
        let doorsViewModel = DoorsViewModel(doorsService: doorsService)

        // Store non-observable services
        self.keyStore = keyStore
        self.credentialsStore = credentialsStore
        self.apiClient = apiClient
        self.authService = authService
        self.doorsService = doorsService

        // Store managers and view models as StateObjects
        _locationManager = StateObject(wrappedValue: locationManager)
        _nearestDoorManager = StateObject(wrappedValue: nearestDoorManager)
        _authViewModel = StateObject(wrappedValue: authViewModel)
        _doorsViewModel = StateObject(wrappedValue: doorsViewModel)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.keyStore, keyStore)
                .environment(\.credentialsStore, credentialsStore)
                .environment(\.apiClient, apiClient)
                .environment(\.authService, authService)
                .environment(\.doorsService, doorsService)
                .environmentObject(locationManager)
                .environmentObject(nearestDoorManager)
                .environmentObject(authViewModel)
                .environmentObject(doorsViewModel)
        }
    }
}
