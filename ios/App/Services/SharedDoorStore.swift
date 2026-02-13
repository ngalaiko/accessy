import Foundation

/// Shared door cache using App Group UserDefaults for widget access
nonisolated final class SharedDoorStore {
    private static let suiteName = "group.rocks.galaiko.cerve"
    private static let doorsKey = "cached_doors"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: SharedDoorStore.suiteName)
    }

    func saveDoors(_ doors: [Door]) {
        guard let data = try? JSONEncoder().encode(doors) else { return }
        defaults?.set(data, forKey: SharedDoorStore.doorsKey)
    }

    func loadDoors() -> [Door] {
        guard let data = defaults?.data(forKey: SharedDoorStore.doorsKey),
              let doors = try? JSONDecoder().decode([Door].self, from: data) else {
            return []
        }
        return doors
    }

    var favoriteDoors: [Door] {
        loadDoors().filter { $0.favorite }
    }
}
