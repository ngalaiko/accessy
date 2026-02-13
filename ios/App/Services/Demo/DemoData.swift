import CoreLocation
import Foundation

/// Demo mode data for App Store review
nonisolated enum DemoData {
    // MARK: - Demo Phone Numbers

    static let demoPhoneNumbers = [
        "+46700000000",
        "demo",
        "+15555555555",
        "0700000000"
    ]

    static func isDemoPhoneNumber(_ phoneNumber: String) -> Bool {
        demoPhoneNumbers.contains(phoneNumber)
    }

    // MARK: - Sample Doors

    static let sampleDoors: [Door] = [
        Door(
            publicationId: "demo-door-1",
            name: "Main Entrance",
            asset: Door.Asset(
                id: "demo-asset-1",
                name: "Main Building Door",
                operations: [
                    Door.Operation(id: "demo-op-1", name: "Unlock")
                ],
                position2d: Door.Position(latitude: 57.7089, longitude: 11.9746)
            ),
            favorite: true
        ),
        Door(
            publicationId: "demo-door-2",
            name: "Office Reception",
            asset: Door.Asset(
                id: "demo-asset-2",
                name: "Reception Door",
                operations: [
                    Door.Operation(id: "demo-op-2", name: "Unlock")
                ],
                position2d: Door.Position(latitude: 57.7092, longitude: 11.9750)
            ),
            favorite: false
        ),
        Door(
            publicationId: "demo-door-3",
            name: "Parking Garage",
            asset: Door.Asset(
                id: "demo-asset-3",
                name: "Garage Gate",
                operations: [
                    Door.Operation(id: "demo-op-3", name: "Open")
                ],
                position2d: Door.Position(latitude: 57.7087, longitude: 11.9742)
            ),
            favorite: false
        ),
        Door(
            publicationId: "demo-door-4",
            name: "Conference Room A",
            asset: Door.Asset(
                id: "demo-asset-4",
                name: "Meeting Room Door",
                operations: [
                    Door.Operation(id: "demo-op-4", name: "Unlock")
                ],
                position2d: Door.Position(latitude: 57.7090, longitude: 11.9748)
            ),
            favorite: true
        ),
        Door(
            publicationId: "demo-door-5",
            name: "Side Entrance",
            asset: Door.Asset(
                id: "demo-asset-5",
                name: "Secondary Building Door",
                operations: [
                    Door.Operation(id: "demo-op-5", name: "Unlock")
                ],
                position2d: Door.Position(latitude: 57.7088, longitude: 11.9744)
            ),
            favorite: false
        ),
        Door(
            publicationId: "demo-door-6",
            name: "Rooftop Access",
            asset: Door.Asset(
                id: "demo-asset-6",
                name: "Rooftop Door",
                operations: [
                    Door.Operation(id: "demo-op-6", name: "Unlock")
                ],
                position2d: Door.Position(latitude: 57.7091, longitude: 11.9749)
            ),
            favorite: false
        )
    ]

    // MARK: - Mock Credentials

    static func createDemoCredentials() -> Credentials {
        Credentials(
            authToken: "demo-auth-token",
            deviceId: "demo-device-id",
            userId: "demo-user-id",
            certBase64: "demo-cert-base64",
            isDemoMode: true
        )
    }
}
