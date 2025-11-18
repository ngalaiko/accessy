import CoreLocation
import Foundation

/// Location overrides for specific doors
private let doorLocationOverrides: [String: CLLocationCoordinate2D] = [
    "f9114e43-b180-470f-b953-2d90fb67aa72": CLLocationCoordinate2D(
        latitude: 57.711941,
        longitude: 11.945427
    ), // P.O nr 21
    "b450d23a-451a-49b8-9d9a-07f7bb3ec36c": CLLocationCoordinate2D(
        latitude: 57.711437,
        longitude: 11.946004
    ),
    // United Spaces Theatre Plan 2
    "f96ebb6d-b9ec-422f-905f-8a3b9575ea30": CLLocationCoordinate2D(
        latitude: 57.711603,
        longitude: 11.946576
    ) // United Spaces reception Plan 2
]

/// Service for door operations
final class DoorsService {
    private let apiClient: APIClient
    private let keyStore: KeychainService
    private let tokenRefreshService: TokenRefreshService

    init(apiClient: APIClient, keyStore: KeychainService, tokenRefreshService: TokenRefreshService) {
        self.apiClient = apiClient
        self.keyStore = keyStore
        self.tokenRefreshService = tokenRefreshService
    }

    // MARK: - Door Operations

    /// Fetch list of available doors
    func getDoors(credentials: Credentials) async throws -> [Door] {
        // Demo mode: return sample doors
        if credentials.isDemoMode {
            return DemoData.sampleDoors
        }

        // Get valid token (auto-refreshes if expired)
        let token = try await tokenRefreshService.getValidToken()

        do {
            let response = try await apiClient.getDoors(authToken: token)
            return response.mostInvokedPublicationsList.map { fixDoor($0) }
        } catch APIError.unauthorized {
            // Token might have expired during request - force refresh and retry once
            let newToken = try await tokenRefreshService.forceRefresh()
            let response = try await apiClient.getDoors(authToken: newToken)
            return response.mostInvokedPublicationsList.map { fixDoor($0) }
        }
    }

    /// Apply location overrides to a door if available
    private func fixDoor(_ door: Door) -> Door {
        guard let override = doorLocationOverrides[door.id] else {
            return door
        }

        let newPosition = Door.Position(latitude: override.latitude, longitude: override.longitude)
        let newAsset = Door.Asset(
            id: door.asset.id,
            name: door.asset.name,
            operations: door.asset.operations,
            position2d: newPosition
        )

        return Door(
            publicationId: door.publicationId,
            name: door.name,
            asset: newAsset,
            favorite: door.favorite
        )
    }

    /// Unlock a specific door by ID
    func unlockDoor(doorId: String, credentials: Credentials) async throws {
        // Demo mode: simulate unlock without API call
        if credentials.isDemoMode {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return
        }

        // Get all doors to find the requested one
        let doors = try await getDoors(credentials: credentials)

        guard let door = doors.first(where: { $0.id == doorId }) else {
            throw DoorsServiceError.doorNotFound
        }

        guard let operation = door.operations.first else {
            throw DoorsServiceError.noOperationsAvailable
        }

        // Load private key from Keychain
        let privateKey = try keyStore.loadKey(identifier: credentials.loginKeyIdentifier)

        // Create authentication proof
        let proof = try Signing.createProof(certBase64: credentials.certBase64, privateKey: privateKey)

        // Get valid token (auto-refreshes if expired)
        let token = try await tokenRefreshService.getValidToken()

        do {
            // Execute unlock operation
            try await apiClient.unlockDoor(operationId: operation.id, proof: proof, authToken: token)
        } catch APIError.unauthorized {
            // Token might have expired during request - force refresh and retry once
            let newToken = try await tokenRefreshService.forceRefresh()
            try await apiClient.unlockDoor(operationId: operation.id, proof: proof, authToken: newToken)
        }
    }

    /// Unlock a door
    func unlockDoor(_ door: Door, credentials: Credentials) async throws {
        // Demo mode: simulate unlock without API call
        if credentials.isDemoMode {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return
        }

        guard let operation = door.operations.first else {
            throw DoorsServiceError.noOperationsAvailable
        }

        // Load private key from Keychain
        let privateKey = try keyStore.loadKey(identifier: credentials.loginKeyIdentifier)

        // Create authentication proof
        let proof = try Signing.createProof(certBase64: credentials.certBase64, privateKey: privateKey)

        // Get valid token (auto-refreshes if expired)
        let token = try await tokenRefreshService.getValidToken()

        do {
            // Execute unlock operation
            try await apiClient.unlockDoor(operationId: operation.id, proof: proof, authToken: token)
        } catch APIError.unauthorized {
            // Token might have expired during request - force refresh and retry once
            let newToken = try await tokenRefreshService.forceRefresh()
            try await apiClient.unlockDoor(operationId: operation.id, proof: proof, authToken: newToken)
        }
    }

    /// Find nearest door based on current location
    func findNearestDoor(doors: [Door], currentLocation: CLLocation) -> (door: Door, distance: CLLocationDistance)? {
        let doorsWithLocation = doors.filter { $0.asset.position2d != nil }

        guard let nearest = doorsWithLocation.min(by: { door1, door2 in
            guard let pos1 = door1.asset.position2d,
                  let pos2 = door2.asset.position2d else {
                return false
            }

            let loc1 = CLLocation(latitude: pos1.latitude, longitude: pos1.longitude)
            let loc2 = CLLocation(latitude: pos2.latitude, longitude: pos2.longitude)

            let dist1 = currentLocation.distance(from: loc1)
            let dist2 = currentLocation.distance(from: loc2)

            return dist1 < dist2
        }), let position = nearest.asset.position2d else {
            return nil
        }

        let doorLocation = CLLocation(latitude: position.latitude, longitude: position.longitude)
        let distance = currentLocation.distance(from: doorLocation)

        return (nearest, distance)
    }

    /// Toggle favorite status for a door
    func toggleFavorite(doorId: String, isFavorite: Bool, credentials: Credentials) async throws {
        // Demo mode: do nothing
        if credentials.isDemoMode {
            return
        }

        // Get valid token (auto-refreshes if expired)
        let token = try await tokenRefreshService.getValidToken()

        do {
            try await apiClient.setFavorite(publicationId: doorId, isFavorite: isFavorite, authToken: token)
        } catch APIError.unauthorized {
            // Token might have expired during request - force refresh and retry once
            let newToken = try await tokenRefreshService.forceRefresh()
            try await apiClient.setFavorite(publicationId: doorId, isFavorite: isFavorite, authToken: newToken)
        }
    }
}

// MARK: - Errors

enum DoorsServiceError: Error, LocalizedError {
    case doorNotFound
    case noOperationsAvailable

    var errorDescription: String? {
        switch self {
        case .doorNotFound:
            return "Door not found"
        case .noOperationsAvailable:
            return "Door has no unlock operations available"
        }
    }
}
