import AppIntents

struct DoorEntity: AppEntity {
    static var defaultQuery = DoorEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Door"

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct DoorEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DoorEntity] {
        let doors = SharedDoorStore().loadDoors()
        return doors.filter { identifiers.contains($0.id) }
            .map { DoorEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [DoorEntity] {
        SharedDoorStore().loadDoors()
            .map { DoorEntity(id: $0.id, name: $0.name) }
    }
}
