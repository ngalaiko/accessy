import Foundation

// MARK: - Door

nonisolated struct Door: Codable, Identifiable {
    let publicationId: String
    let name: String
    let asset: Asset
    let favorite: Bool

    var id: String { publicationId }
    var assetId: String { asset.id }
    var assetName: String { asset.name }
    var operations: [Operation] { asset.operations }

    struct Asset: Codable {
        let id: String
        let name: String
        let operations: [Operation]
        let position2d: Position?
    }

    struct Position: Codable {
        let latitude: Double
        let longitude: Double
    }

    struct Operation: Codable, Identifiable {
        let id: String
        let name: String
    }

    enum CodingKeys: String, CodingKey {
        case publicationId = "id"
        case name
        case asset
        case favorite
    }
}

// MARK: - API Responses

nonisolated struct DoorsResponse: Codable {
    let items: [Door]

    var mostInvokedPublicationsList: [Door] {
        items
    }

    enum CodingKeys: String, CodingKey {
        case items
    }
}
