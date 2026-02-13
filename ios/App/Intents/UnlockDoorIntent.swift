import AppIntents

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case noDoorFound
    case locationUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notLoggedIn:
            "Please open Cerve and log in first."
        case .noDoorFound:
            "No doors found near your location."
        case .locationUnavailable:
            "Could not determine your location."
        }
    }
}

struct UnlockDoorIntent: AppIntent {
    static var title: LocalizedStringResource = "Unlock Door"
    static var description: IntentDescription = "Unlocks a specific door."
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Door ID")
    var doorId: String

    init() {}

    init(doorId: String) {
        self.doorId = doorId
    }

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

        try await doorsService.unlockDoor(doorId: doorId, credentials: credentials)

        let store = SharedDoorStore()
        let doorName = store.loadDoors().first(where: { $0.id == doorId })?.name ?? "Door"

        return .result(dialog: "Unlocked \(doorName)")
    }
}
