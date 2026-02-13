import AppIntents

struct CerveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenNearestDoorIntent(),
            phrases: [
                "Open nearest door with \(.applicationName)",
                "Unlock nearest door with \(.applicationName)"
            ],
            shortTitle: "Open Nearest Door",
            systemImageName: "door.left.hand.open"
        )
    }
}
