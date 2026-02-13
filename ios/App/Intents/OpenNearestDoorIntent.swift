import AppIntents
import CoreLocation

struct OpenNearestDoorIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Nearest Door"
    static var description: IntentDescription = "Unlocks the nearest door to your current location."
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let keyStore = KeychainService()
        let credentialsStore = CredentialsService(keyStore: keyStore)
        let apiClient = APIClient()
        let tokenRefreshService = TokenRefreshService(
            apiClient: apiClient,
            keyStore: keyStore,
            credentialsService: credentialsStore
        )
        let doorsService = DoorsService(
            apiClient: apiClient,
            keyStore: keyStore,
            tokenRefreshService: tokenRefreshService
        )

        let credentials: Credentials
        do {
            credentials = try credentialsStore.load()
        } catch {
            throw IntentError.notLoggedIn
        }

        let doors = try await doorsService.getDoors(credentials: credentials)

        let location = try await getCurrentLocation()

        guard let result = doorsService.findNearestDoor(doors: doors, currentLocation: location) else {
            throw IntentError.noDoorFound
        }

        try await doorsService.unlockDoor(result.door, credentials: credentials)

        let distanceStr = String(format: "%.0f", result.distance)
        return .result(dialog: "Opened \(result.door.name) (\(distanceStr)m away)")
    }

    private func getCurrentLocation() async throws -> CLLocation {
        var lastLocation: CLLocation?

        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location,
               location.horizontalAccuracy >= 0,
               location.horizontalAccuracy < 100 {
                return location
            }
            if lastLocation == nil { lastLocation = update.location }

            // Timeout after checking a few updates
            if let loc = lastLocation {
                return loc
            }
        }

        throw IntentError.locationUnavailable
    }
}
